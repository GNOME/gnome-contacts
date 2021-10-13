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
    // { "share-contact", share_contact },
    { "unlink-contact", unlink_contact },
    { "delete-contact", delete_contact },
    { "sort-on", null, "s", "'surname'", sort_on_changed },
    { "undo-operation", undo_operation_action },
    { "undo-delete", undo_delete_action },
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
  private unowned Gtk.Box contact_pane_page;
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

  // The 2 panes the window consists of
  private ListPane list_pane;
  private ContactPane contact_pane;

  // Actions
  private SimpleActionGroup actions = new SimpleActionGroup ();
  private bool delete_cancelled;

  public UiState state { get; set; default = UiState.NORMAL; }

  // Window state
  public int window_width { get; set; }
  public int window_height { get; set; }

  public Settings settings { get; construct set; }

  public Store store {
    get; construct set;
  }

  // If an unduable operation was recently performed, this will be set
  public Operation? last_operation = null;

  construct {
    this.actions.add_action_entries (ACTION_ENTRIES, this);
    this.insert_action_group ("window", this.actions);

    this.notify["state"].connect (on_ui_state_changed);

    this.create_contact_pane ();
    this.connect_button_signals ();
    this.restore_window_state ();

    if (Config.PROFILE == "development")
        this.add_css_class ("devel");
  }

  public MainWindow (Settings settings, App app, Store contacts_store) {
    Object (
      application: app,
      settings: settings,
      store: contacts_store
    );

    unowned var sort_key = this.settings.sort_on_surname? "surname" : "firstname";
    var sort_action = (SimpleAction) this.actions.lookup_action ("sort-on");
    sort_action.set_state (new Variant.string (sort_key));
  }

  private void restore_window_state () {
    // Apply them
    if (this.settings.window_width > 0 && this.settings.window_height > 0)
      set_default_size (this.settings.window_width, this.settings.window_height);
    this.maximized = this.settings.window_maximized;
    this.fullscreened = this.settings.window_fullscreen;
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
    if (this.list_pane != null)
      return;

    this.list_pane = new ListPane (this, this.settings, store);
    bind_property ("state", this.list_pane, "state", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
    this.list_pane.selection_changed.connect (list_pane_selection_changed_cb);
    this.list_pane.link_contacts.connect (list_pane_link_contacts_cb);
    this.list_pane.delete_contacts.connect (delete_contacts);

    this.list_pane.contacts_marked.connect ((nr_contacts) => {
      string left_title = _("Contacts");
      if (this.state == UiState.SELECTING)
        left_title = ngettext ("%d Selected", "%d Selected", nr_contacts)
                                     .printf (nr_contacts);
      this.left_header.title_widget = new Adw.WindowTitle (left_title, "");
    });

    this.list_pane_stack.add_child (this.list_pane);
    this.list_pane_stack.visible_child = this.list_pane;

    if (this.contact_pane.individual != null)
      this.list_pane.select_contact (this.contact_pane.individual);
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
  }

  [GtkCallback]
  private void on_back_clicked () {
    show_list_pane ();
  }

  private void edit_contact (GLib.SimpleAction action, GLib.Variant? parameter) {
    if (this.contact_pane.individual == null)
      return;

    this.state = UiState.UPDATING;

    unowned var name = this.contact_pane.individual.display_name;
    var title = _("Editing %s").printf (name);
    this.right_header.title_widget = new Adw.WindowTitle (title, "");
    this.contact_pane.edit_contact ();
  }

  [GtkCallback]
  private void on_favorite_button_toggled (Gtk.ToggleButton button) {
    // Don't change the contact being favorite while switching between the two of them
    if (this.ignore_favorite_button_toggled)
      return;
    if (this.contact_pane.individual == null)
      return;

    var is_fav = this.contact_pane.individual.is_favourite;
    this.contact_pane.individual.is_favourite = !is_fav;
  }

  [GtkCallback]
  private void on_selection_button_clicked () {
    this.state = UiState.SELECTING;
    var left_title = ngettext ("%d Selected", "%d Selected", 0) .printf (0);
    this.left_header.title_widget = new Adw.WindowTitle (left_title, "");
  }

  private void unlink_contact (GLib.SimpleAction action, GLib.Variant? parameter) {
    unowned var individual = this.contact_pane.individual;
    if (individual == null)
      return;

    set_shown_contact (null);
    this.state = UiState.NORMAL;

    this.last_operation = new UnlinkOperation (this.store, individual);
    this.last_operation.execute.begin ((obj, res) => {
      try {
        this.last_operation.execute.end (res);
      } catch (GLib.Error e) {
        warning ("Error unlinking individuals: %s", e.message);
      }
    });

    var toast = new Adw.Toast (this.last_operation.description);
    toast.set_button_label (_("_Undo"));
    toast.action_name = "window.undo-operation";

    this.toast_overlay.add_toast (toast);
  }

  private void delete_contact (GLib.SimpleAction action, GLib.Variant? parameter) {
    var individual = this.contact_pane.individual;
    if (individual == null)
      return;

    this.list_pane.set_contact_visible (individual, false);
    delete_contacts (new Gee.ArrayList<Individual>.wrap ({ individual }));
  }

  private void sort_on_changed (SimpleAction action, GLib.Variant? new_state) {
    unowned var sort_key = new_state.get_string ();
    this.settings.sort_on_surname = (sort_key == "surname");
    action.set_state (new_state);
  }

  private void undo_operation_action (SimpleAction action, GLib.Variant? parameter) {
    if (this.last_operation == null) {
      warning ("Undo action was called without anything that can be undone?");
      return;
    }

    debug ("Undoing operation '%s'", this.last_operation.description);
    this.last_operation.undo.begin ((obj, res) => {
      try {
        this.last_operation.undo.end (res);
      } catch (GLib.Error e) {
        warning ("Couldn't undo operation '%s': %s", this.last_operation.description, e.message);
      }
      debug ("Finished undoing operation '%s'", this.last_operation.description);
    });
  }

  private void undo_delete_action (SimpleAction action, GLib.Variant? parameter) {
    this.delete_cancelled = true;
  }

  private void stop_editing (bool cancel = false) {
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
    this.list_pane.scroll_to_contact ();

    this.right_header.title_widget = new Adw.WindowTitle ("", "");
  }

  public void set_shown_contact (Individual? i) {
    /* FIXME: ask the user to leave edit-mode and act accordingly */
    if (this.contact_pane.on_edit_mode)
      stop_editing ();

    this.contact_pane.show_contact (i);
    if (list_pane != null)
      list_pane.select_contact (i);

    // clearing right_header
    this.right_header.title_widget = new Adw.WindowTitle ("", "");
    if (i != null) {
      this.ignore_favorite_button_toggled = true;
      this.favorite_button.active = i.is_favourite;
      this.ignore_favorite_button_toggled = false;
      this.favorite_button.tooltip_text = (i.is_favourite)? _("Unmark as favorite")
                                                          : _("Mark as favorite");
    }
  }

  public void new_contact (GLib.SimpleAction action, GLib.Variant? parameter) {
    if (this.state == UiState.UPDATING || this.state == UiState.CREATING)
      return;

    this.list_pane.select_contact (null);

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
      this.list_pane.select_contact (null);
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
    this.list_pane.filter_entry.set_text (query);
  }

  private void connect_button_signals () {
    this.select_cancel_button.clicked.connect (() => {
        if (this.contact_pane.individual != null) {
            this.state = UiState.SHOWING;
        } else {
            this.state = UiState.NORMAL;
        }
    });
    this.done_button.clicked.connect (() => stop_editing ());
    this.cancel_button.clicked.connect (() => stop_editing (true));

    this.contact_pane.notify["individual"].connect (() => {
      unowned var individual = this.contact_pane.individual;
      if (individual == null)
        return;

      var unlink_action = this.actions.lookup_action ("unlink-contact");
      ((SimpleAction) unlink_action).set_enabled (individual.personas.size > 1);
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

  private void list_pane_selection_changed_cb (Individual? new_selection) {
    set_shown_contact (new_selection);
    if (this.state != UiState.SELECTING)
      this.state = UiState.SHOWING;

    if (new_selection != null)
      show_contact_pane ();
  }

  private void list_pane_link_contacts_cb (Gee.LinkedList<Individual> contact_list) {
    set_shown_contact (null);
    this.state = UiState.NORMAL;

    this.last_operation = new LinkOperation (this.store, contact_list);
    this.last_operation.execute.begin ((obj, res) => {
      try {
        this.last_operation.execute.end (res);
      } catch (GLib.Error e) {
        warning ("Error linking individuals: %s", e.message);
      }
    });

    var toast = new Adw.Toast (this.last_operation.description);
    toast.set_button_label (_("_Undo"));
    toast.action_name = "window.undo-operation";
    this.toast_overlay.add_toast (toast);
  }

  private void delete_contacts (Gee.List<Individual> individuals) {
    set_shown_contact (null);
    this.state = UiState.NORMAL;

    this.last_operation = new DeleteOperation (individuals);
    var toast = new Adw.Toast (this.last_operation.description);
    toast.set_button_label (_("_Undo"));
    toast.action_name = "window.undo-delete";

    this.delete_cancelled = false;
    toast.dismissed.connect (() => {
        if (this.delete_cancelled) {
          this.list_pane.set_contact_visible (individuals[0], true);
          set_shown_contact (individuals[0]);
          this.state = UiState.SHOWING;
        } else {
          this.last_operation.execute.begin ((obj, res) => {
              try {
                this.last_operation.execute.end (res);
              } catch (Error e) {
                debug ("Coudln't remove persona: %s", e.message);
              }
          });
        }
    });

    this.toast_overlay.add_toast (toast);
  }

  private void contact_pane_contacts_linked_cb (string? main_contact, string linked_contact, LinkOperation operation) {
    this.last_operation = operation;
    var toast = new Adw.Toast (this.last_operation.description);
    toast.set_button_label (_("_Undo"));
    toast.action_name = "window.undo-operation";
    this.toast_overlay.add_toast (toast);
  }
}
