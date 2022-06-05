/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-main-window.ui")]
public class Contacts.MainWindow : Adw.ApplicationWindow {

  private const GLib.ActionEntry[] ACTION_ENTRIES = {
    { "new-contact", new_contact },
    { "edit-contact", edit_contact },
    { "stop-editing-contact", stop_editing_contact, "b" },
    { "link-marked-contacts", link_marked_contacts },
    { "delete-marked-contacts", delete_marked_contacts },
    // { "share-contact", share_contact },
    { "unlink-contact", unlink_contact },
    { "delete-contact", delete_contact },
    { "sort-on", null, "s", "'surname'", sort_on_changed },
    { "undo-operation", undo_operation_action, "s" },
    { "cancel-operation", cancel_operation_action, "s" },
  };

  [GtkChild]
  private unowned Adw.Leaflet content_box;
  [GtkChild]
  private unowned Gtk.Revealer back_revealer;
  [GtkChild]
  private unowned Gtk.Stack list_pane_stack;
  [GtkChild]
  private unowned Gtk.Overlay contact_pane_container;
  [GtkChild]
  private unowned Gtk.Box list_pane_page;
  [GtkChild]
  private unowned Gtk.Widget list_pane;
  [GtkChild]
  public unowned Gtk.SearchEntry filter_entry;
  [GtkChild]
  private unowned Adw.Bin contacts_list_container;
  private unowned ContactList contacts_list;

  [GtkChild]
  private unowned Gtk.Box contact_pane_page;
  private ContactPane contact_pane;
  [GtkChild]
  private unowned Adw.HeaderBar left_header;
  [GtkChild]
  private unowned Adw.HeaderBar right_header;
  [GtkChild]
  private unowned Adw.ToastOverlay toast_overlay;
  [GtkChild]
  private unowned Gtk.Button select_cancel_button;
  [GtkChild]
  private unowned Gtk.MenuButton hamburger_menu_button;
  [GtkChild]
  private unowned Gtk.Box contact_sheet_buttons;
  [GtkChild]
  private unowned Gtk.ToggleButton favorite_button;
  private bool ignore_favorite_button_toggled;
  [GtkChild]
  private unowned Gtk.Button add_button;
  [GtkChild]
  private unowned Gtk.Button cancel_button;
  [GtkChild]
  private unowned Gtk.Button done_button;
  [GtkChild]
  private unowned Gtk.Button selection_button;

  [GtkChild]
  private unowned Gtk.ActionBar actions_bar;

  public UiState state { get; set; default = UiState.NORMAL; }

  // Window state
  public int window_width { get; set; }
  public int window_height { get; set; }

  public Settings settings { get; construct set; }

  public Store store { get; construct set; }

  public Contacts.OperationList operations { get; construct set; }

  // A separate SelectionModel for all marked contacts
  private Gtk.MultiSelection marked_contacts;

  construct {
    add_action_entries (ACTION_ENTRIES, this);

    this.store.selection.notify["selected-item"].connect (on_selection_changed);

    this.marked_contacts = new Gtk.MultiSelection (this.store.filter_model);
    this.marked_contacts.selection_changed.connect (on_marked_contacts_changed);
    this.marked_contacts.unselect_all (); // Call here to sync actions

    this.filter_entry.set_key_capture_widget (this);

    this.notify["state"].connect (on_ui_state_changed);

    this.create_list_pane ();
    this.create_contact_pane ();
    this.connect_button_signals ();
    this.restore_window_state ();

    if (Config.PROFILE == "development")
        this.add_css_class ("devel");
  }

  public MainWindow (Settings settings,
                     OperationList operations,
                     App app,
                     Store contacts_store) {
    Object (
      application: app,
      operations: operations,
      settings: settings,
      store: contacts_store
    );

    unowned var sort_key = this.settings.sort_on_surname? "surname" : "firstname";
    var sort_action = (SimpleAction) this.lookup_action ("sort-on");
    sort_action.set_state (new Variant.string (sort_key));
  }

  private void restore_window_state () {
    // Apply them
    if (this.settings.window_width > 0 && this.settings.window_height > 0)
      set_default_size (this.settings.window_width, this.settings.window_height);
    this.maximized = this.settings.window_maximized;
    this.fullscreened = this.settings.window_fullscreen;
  }

  private void create_list_pane () {
    var contactslist = new ContactList (this.store, this.marked_contacts);
    bind_property ("state", contactslist, "state", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
    this.contacts_list = contactslist;
    this.contacts_list_container.set_child (contactslist);
  }

  private void create_contact_pane () {
    this.contact_pane = new ContactPane (this, this.store);
    this.contact_pane.visible = true;
    this.contact_pane.hexpand = true;
    this.contact_pane.contacts_linked.connect (contact_pane_contacts_linked_cb);
    this.contact_pane_container.set_child (this.contact_pane);
  }

  /**
   * This shows the contact list on the left. This needs to be called
   * explicitly when contacts are loaded, as the original setup will
   * only show a loading spinner.
   */
  public void show_contact_list () {
    // FIXME: if no contact is loaded per backend, I must place a sign
    // saying "import your contacts/add online account"
    this.list_pane_stack.visible_child = this.list_pane;
  }

  private void on_marked_contacts_changed (Gtk.SelectionModel marked,
                                           uint position,
                                           uint n_changed) {
    var n_selected = marked.get_selection ().get_size ();

    // Update related actions
    unowned var action = lookup_action ("delete-marked-contacts");
    ((SimpleAction) action).set_enabled (n_selected > 0);

    action = lookup_action ("link-marked-contacts");
    ((SimpleAction) action).set_enabled (n_selected > 1);

    string left_title = _("Contacts");
    if (this.state == UiState.SELECTING) {
      left_title = ngettext ("%llu Selected", "%llu Selected", (ulong) n_selected)
                                   .printf (n_selected);
    }
    this.left_header.title_widget = new Adw.WindowTitle (left_title, "");
  }

  private void on_ui_state_changed (Object obj, ParamSpec pspec) {
    // UI when we're not editing of selecting stuff
    this.add_button.visible
        = this.hamburger_menu_button.visible
        = (this.state == UiState.NORMAL || this.state == UiState.SHOWING);

    // UI when showing a contact
    this.contact_sheet_buttons.visible
      = (this.state == UiState.SHOWING);

    // Selecting UI
    this.select_cancel_button.visible = (this.state == UiState.SELECTING);
    this.selection_button.visible = !(this.state == UiState.SELECTING || this.state.editing ());

    if (this.state != UiState.SELECTING)
      this.left_header.title_widget = new Adw.WindowTitle (_("Contacts"), "");

    // Editing UI
    this.cancel_button.visible
        = this.done_button.visible
        = this.right_header.show_end_title_buttons
        = this.state.editing ();
    this.right_header.show_end_title_buttons = !this.state.editing ();
    if (this.state.editing ()) {
      this.done_button.label = (this.state == UiState.CREATING)? _("_Add") : _("Done");
      // Cast is required because Gtk.Button.set_focus_on_click is deprecated and
      // we have to use Gtk.Widget.set_focus_on_click instead
      this.done_button.set_focus_on_click (true);
    }

    // Allow the back gesture when not browsing
    this.content_box.can_navigate_back = this.state == UiState.NORMAL ||
                                         this.state == UiState.SHOWING ||
                                         this.state == UiState.SELECTING;

    // Disable when editing a contact
    this.filter_entry.sensitive
        = this.contacts_list.sensitive
        = !this.state.editing ();

    this.actions_bar.revealed = (this.state == UiState.SELECTING);
  }

  [GtkCallback]
  private void on_back_clicked () {
    show_list_pane ();
  }

  private void edit_contact (GLib.SimpleAction action, GLib.Variant? parameter) {
    unowned var selected = this.store.get_selected_contact ();
    return_if_fail (selected != null);

    this.state = UiState.UPDATING;

    var title = _("Editing %s").printf (selected.display_name);
    this.right_header.title_widget = new Adw.WindowTitle (title, "");
    this.contact_pane.edit_contact ();
  }

  [GtkCallback]
  private void on_favorite_button_toggled (Gtk.ToggleButton button) {
    // Don't change the contact being favorite while switching between the two of them
    if (this.ignore_favorite_button_toggled)
      return;

    unowned var selected = this.store.get_selected_contact ();
    return_if_fail (selected != null);

    selected.is_favourite = !selected.is_favourite;
  }

  [GtkCallback]
  private void on_selection_button_clicked () {
    this.state = UiState.SELECTING;
    var left_title = ngettext ("%d Selected", "%d Selected", 0) .printf (0);
    this.left_header.title_widget = new Adw.WindowTitle (left_title, "");
  }

  private void unlink_contact (GLib.SimpleAction action, GLib.Variant? parameter) {
    unowned Individual? selected = this.store.get_selected_contact ();
    return_if_fail (selected != null);

    this.store.selection.unselect_all ();
    this.state = UiState.NORMAL;

    var operation = new UnlinkOperation (this.store, selected);
    this.operations.execute.begin (operation, null, (obj, res) => {
      try {
        this.operations.execute.end (res);
      } catch (GLib.Error e) {
        warning ("Error unlinking individuals: %s", e.message);
      }
    });

    add_toast_for_operation (operation, "win.undo-operation", _("_Undo"));
  }

  private void delete_contact (GLib.SimpleAction action, GLib.Variant? parameter) {
    var selection = this.store.selection.get_selection ().copy ();
    if (selection.is_empty ())
      return;

    this.contacts_list.set_contacts_visible (selection, false);
    this.contact_pane.show_contact (null);
    delete_contacts (selection);
  }

  private void sort_on_changed (SimpleAction action, GLib.Variant? new_state) {
    unowned var sort_key = new_state.get_string ();
    this.settings.sort_on_surname = (sort_key == "surname");
    action.set_state (new_state);
  }

  private void undo_operation_action (SimpleAction action, GLib.Variant? parameter) {
    unowned var uuid = parameter.get_string ();
    this.operations.undo_operation.begin (uuid, (obj, res) => {
      try {
        this.operations.undo_operation.end (res);
      } catch (GLib.Error e) {
        warning ("Couldn't undo operation '%s': %s", uuid, e.message);
      }
    });
  }

  private void cancel_operation_action (SimpleAction action, GLib.Variant? parameter) {
    unowned var uuid = parameter.get_string ();
    this.operations.cancel_operation.begin (uuid, (obj, res) => {
      try {
        this.operations.cancel_operation.end (res);
      } catch (GLib.Error e) {
        warning ("Couldn't cancel operation '%s': %s", uuid, e.message);
      }
    });
  }

  private void stop_editing_contact (SimpleAction action, GLib.Variant? parameter) {
    bool cancel = parameter.get_boolean ();

    if (this.state == UiState.CREATING) {
      if (cancel) {
        show_list_pane ();
      }
      this.state = UiState.NORMAL;
    } else {
      show_contact_pane ();
      this.state = UiState.SHOWING;
    }
    this.contact_pane.stop_editing (cancel);
    this.contacts_list.scroll_to_selected ();

    this.right_header.title_widget = new Adw.WindowTitle ("", "");
  }

  public void new_contact (GLib.SimpleAction action, GLib.Variant? parameter) {
    if (this.state == UiState.UPDATING || this.state == UiState.CREATING)
      return;

    this.store.selection.unselect_all ();

    this.state = UiState.CREATING;

    this.right_header.title_widget = new Adw.WindowTitle (_("New Contact"), "");

    this.contact_pane.new_contact ();
    show_contact_pane ();
  }

  [GtkCallback]
  private void on_cancel_visible () {
    update_header ();
  }

  [GtkCallback]
  private void on_folded () {
    update_header ();
  }

  [GtkCallback]
  private void on_child_transition_running () {
    if (!this.content_box.child_transition_running &&
         this.content_box.visible_child == this.list_pane_page)
      this.store.selection.unselect_all ();
  }

  private void update_header () {
    this.back_revealer.reveal_child =
      this.back_revealer.visible =
        this.content_box.folded &&
        !this.cancel_button.visible &&
        this.content_box.visible_child == this.contact_pane_page;
  }

  private void show_list_pane () {
    this.content_box.navigate (Adw.NavigationDirection.BACK);
    update_header ();
  }

  private void show_contact_pane () {
    this.content_box.navigate (Adw.NavigationDirection.FORWARD);
    update_header ();
  }

  public void show_search (string query) {
    this.filter_entry.set_text (query);
  }

  private void connect_button_signals () {
    this.select_cancel_button.clicked.connect (() => {
        this.marked_contacts.unselect_all ();
        if (this.store.selection.get_selected () != Gtk.INVALID_LIST_POSITION) {
            this.state = UiState.SHOWING;
        } else {
            this.state = UiState.NORMAL;
        }
    });
  }

  public override bool close_request () {
    // Clear the contacts so any changed information is stored
    this.contact_pane.show_contact (null);

    this.settings.window_width = this.default_width;
    this.settings.window_height = this.default_height;
    this.settings.window_maximized = this.maximized;
    this.settings.window_fullscreen = this.fullscreened;

    return base.close_request ();
  }

  private void on_selection_changed (Object object, ParamSpec pspec) {
    unowned var selected = this.store.get_selected_contact ();

    // Update related actions
    unowned var unlink_action = lookup_action ("unlink-contact");
    ((SimpleAction) unlink_action).set_enabled (selected.personas.size > 1);

    // We really want to treat selection mode specially
    if (this.state != UiState.SELECTING) {
      // FIXME: ask the user to leave edit-mode and act accordingly
      if (this.contact_pane.on_edit_mode)
        activate_action ("stop-editing-contact", new Variant.boolean (false));

      this.contact_pane.show_contact (selected);

      // clearing right_header
      this.right_header.title_widget = new Adw.WindowTitle ("", "");
      if (selected == null) {
        this.ignore_favorite_button_toggled = true;
        this.favorite_button.active = selected.is_favourite;
        this.ignore_favorite_button_toggled = false;
        if (selected.is_favourite)
          this.favorite_button.tooltip_text = _("Unmark as favorite");
        else
          this.favorite_button.tooltip_text = _("Mark as favorite");
      }
      this.state = UiState.SHOWING;
      if (selected == null)
        show_contact_pane ();
    }
  }

  private void link_marked_contacts (GLib.SimpleAction action, GLib.Variant? parameter) {
    // Take a copy, since we'll unselect everything later
    var selection = this.marked_contacts.get_selection ().copy ();

    // Go back to normal state as much as possible, and hide the contacts that
    // will be linked together
    this.store.selection.unselect_all ();
    this.marked_contacts.unselect_all ();
    this.contacts_list.set_contacts_visible (selection, false);
    this.contact_pane.show_contact (null);
    this.state = UiState.NORMAL;

    // Build the list of contacts
    var list = bitset_to_individuals (this.marked_contacts,
                                      selection);

    // Perform the operation
    var operation = new LinkOperation (this.store, list);
    this.operations.execute.begin (operation, null, (obj, res) => {
      try {
        this.operations.execute.end (res);
      } catch (GLib.Error e) {
        warning ("Error linking individuals: %s", e.message);
      }
    });

    add_toast_for_operation (operation, "win.undo-operation", _("_Undo"));
  }

  private void delete_marked_contacts (GLib.SimpleAction action, GLib.Variant? parameter) {
    var selection = this.marked_contacts.get_selection ().copy ();
    delete_contacts (selection);
  }

  private void delete_contacts (Gtk.Bitset selection) {
    // Go back to normal state as much as possible, and hide the contacts that
    // will be deleted
    this.store.selection.unselect_all ();
    this.marked_contacts.unselect_all ();
    this.contacts_list.set_contacts_visible (selection, false);
    this.contact_pane.show_contact (null);
    this.state = UiState.NORMAL;

    var individuals = bitset_to_individuals (this.store.filter_model,
                                             selection);

    // NOTE: we'll do this with a timeout, since the operation is not reversable
    var op = new DeleteOperation (individuals);

    var cancellable = new Cancellable ();
    cancellable.cancelled.connect ((c) => {
      this.contacts_list.set_contacts_visible (selection, true);
    });

    var toast = add_toast_for_operation (op, "win.cancel-operation", _("_Cancel"));
    this.operations.execute_with_timeout.begin (op, toast.timeout, cancellable, (obj, res) => {
      try {
        this.operations.execute_with_timeout.end (res);
      } catch (GLib.Error e) {
        warning ("Error removing individuals: %s", e.message);
      }
    });
  }

  private void contact_pane_contacts_linked_cb (LinkOperation operation) {
    add_toast_for_operation (operation, "win.undo-operation", _("_Undo"));

    this.operations.execute.begin (operation, null, (obj, res) => {
      try {
        this.operations.execute.end (res);
      } catch (GLib.Error e) {
        warning ("Error linking individuals: %s", e.message);
      }
    });
  }

  private Adw.Toast add_toast_for_operation (Operation operation,
                                             string? action_name = null,
                                             string? action_label = null) {
    var toast = new Adw.Toast (operation.description);
    if (action_name != null) {
      toast.set_button_label (action_label);
      toast.action_name = action_name;
      toast.action_target = operation.uuid;
    }
    this.toast_overlay.add_toast (toast);
    return toast;
  }

  // Little helper
  private Gee.LinkedList<Individual> bitset_to_individuals (GLib.ListModel model,
                                                            Gtk.Bitset bitset) {
    var list = new Gee.LinkedList<Individual> ();

    var iter = Gtk.BitsetIter ();
    uint index;
    if (!iter.init_first (bitset, out index))
      return list;

    do {
      list.add ((Individual) model.get_item (index));
    } while (iter.next (out index));

    return list;
  }

  [GtkCallback]
  private void filter_entry_changed (Gtk.Editable editable) {
    unowned var query = this.store.filter.query as SimpleQuery;
    query.query_string = this.filter_entry.text;
  }
}
