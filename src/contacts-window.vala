/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
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

using Gee;
using Gtk;
using Hdy;
using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-window.ui")]
public class Contacts.Window : Gtk.ApplicationWindow {
  [GtkChild]
  private Leaflet header;
  [GtkChild]
  private Leaflet content_box;
  [GtkChild]
  private Revealer back_revealer;
  [GtkChild]
  private Stack list_pane_stack;
  [GtkChild]
  private Container contact_pane_container;
  [GtkChild]
  private TitleBar titlebar;
  [GtkChild]
  private Gtk.HeaderBar left_header;
  [GtkChild]
  private Gtk.HeaderBar right_header;
  [GtkChild]
  private Overlay notification_overlay;
  [GtkChild]
  private Button add_button;
  [GtkChild]
  private Button select_cancel_button;
  [GtkChild]
  private MenuButton hamburger_menu_button;
  [GtkChild]
  private ModelButton sort_on_firstname_button;
  [GtkChild]
  private ModelButton sort_on_surname_button;
  [GtkChild]
  private ToggleButton favorite_button;
  private bool ignore_favorite_button_toggled;
  [GtkChild]
  private Button edit_button;
  [GtkChild]
  private Button cancel_button;
  [GtkChild]
  private Button done_button;
  // Somehow needed for the header group to work
  [GtkChild]
  private HeaderGroup header_group;

  // The 2 panes the window consists of
  private ListPane list_pane;
  private ContactPane contact_pane;

  public UiState state { get; set; default = UiState.NORMAL; }

  /** Holds the current width. */
  public int window_width { get; set; }
  private const string WINDOW_WIDTH_PROP = "window-width";

  /** Holds the current height. */
  public int window_height { get; set; }
  private const string WINDOW_HEIGHT_PROP = "window-height";

  /** Holds true if the window is currently maximized. */
  public bool window_maximized { get; set; }
  private const string WINDOW_MAXIMIZED_PROP = "window-maximized";

  private Settings settings;

  public Store store {
    get; construct set;
  }

  public Window (Settings settings, App app, Store contacts_store) {
    Object (
      application: app,
      show_menubar: false,
      store: contacts_store
    );

    this.settings = settings;
    this.sort_on_firstname_button.clicked.connect (() => {
      this.settings.sort_on_surname = false;
      on_sort_changed ();
    });
    this.sort_on_surname_button.clicked.connect (() => {
      this.settings.sort_on_surname = true;
      on_sort_changed ();
    });
    on_sort_changed ();

    this.notify["state"].connect (on_ui_state_changed);

    bind_dimension_properties_to_settings ();
    create_contact_pane ();
    connect_button_signals ();
    restore_window_size_and_position_from_settings ();
  }

  private void on_sort_changed () {
    this.sort_on_firstname_button.active = !this.settings.sort_on_surname;
    this.sort_on_surname_button.active = this.settings.sort_on_surname;
  }

  private void restore_window_size_and_position_from_settings () {
    var screen = get_screen();
    if (screen != null && this.window_width <= screen.get_width () && this.window_height <= screen.get_height ()) {
      set_default_size (this.window_width, this.window_height);
    }
    if (this.window_maximized) {
      maximize();
    }
    // always put the window into the center position to avoid losing it somewhere at the screen boundaries.
    this.window_position = Gtk.WindowPosition.CENTER;
  }

  public override bool window_state_event (Gdk.EventWindowState event) {
    if (!(Gdk.WindowState.WITHDRAWN in event.new_window_state)) {
      bool maximized = (Gdk.WindowState.MAXIMIZED in event.new_window_state);
      if (this.window_maximized != maximized)
        this.window_maximized = maximized;
    }
    return base.window_state_event (event);
  }

  // Called on window resize. Save window size for the next start.
  public override void size_allocate (Gtk.Allocation allocation) {
    base.size_allocate (allocation);

    var screen = get_screen ();
    if (screen != null && !this.window_maximized) {
      // Get the size via ::get_size instead of the allocation
      // so that the window isn't ever-expanding.
      int width = 0;
      int height = 0;
      get_size(out width, out height);

      // Only store if the values have changed and are
      // reasonable-looking.
      if (this.window_width != width && width > 0 && width <= screen.get_width ()) {
        this.window_width = width;
      }
      if (this.window_height != height && height > 0 && height <= screen.get_height ()) {
        this.window_height = height;
      }
    }
  }

  private void create_contact_pane () {
    this.contact_pane = new ContactPane (this, this.store);
    this.contact_pane.visible = true;
    this.contact_pane.hexpand = true;
    this.contact_pane.will_delete.connect ( (contact) => {
        delete_contacts (new ArrayList<Contact>.wrap ({ contact }));
     });
    this.contact_pane.contacts_linked.connect (contact_pane_contacts_linked_cb);
    this.contact_pane.display_name_changed.connect ((display_name) => {
      this.right_header.title = display_name;
    });
    this.contact_pane_container.add (this.contact_pane);
  }

  public void set_list_pane () {
    /* FIXME: if no contact is loaded per backend, I must place a sign
     * saying "import your contacts/add online account" */
    if (list_pane != null)
      return;

    list_pane = new ListPane (this.settings, store);
    bind_property ("state", this.list_pane, "state", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
    list_pane.selection_changed.connect (list_pane_selection_changed_cb);
    list_pane.link_contacts.connect (list_pane_link_contacts_cb);
    list_pane.delete_contacts.connect (delete_contacts);

    list_pane.contacts_marked.connect ((nr_contacts) => {
        if (nr_contacts != 0)
          this.left_header.title = ngettext ("%d Selected", "%d Selected", nr_contacts)
                                       .printf (nr_contacts);
      });

    list_pane_stack.add (list_pane);
    list_pane.show ();
    list_pane_stack.visible_child = list_pane;

    if (this.contact_pane.contact != null)
      list_pane.select_contact (this.contact_pane.contact);

  }

  private void on_ui_state_changed (Object obj, ParamSpec pspec) {
    // UI when we're not editing of selecting stuff
    this.add_button.visible
        = this.hamburger_menu_button.visible
        = this.left_header.show_close_button
        = this.right_header.show_close_button
        = (this.state == UiState.NORMAL || this.state == UiState.SHOWING);

    // UI when showing a contact
    this.edit_button.visible
        = this.favorite_button.visible
        = (this.state == UiState.SHOWING);

    // Selecting UI
    this.select_cancel_button.visible = (this.state == UiState.SELECTING);

    if (this.state != UiState.SELECTING)
      this.left_header.title = _("Contacts");

    // Editing UI
    this.cancel_button.visible
        = this.done_button.visible
        = this.state.editing ();
    if (this.state.editing ()) {
      this.done_button.label = (this.state == UiState.CREATING)? _("Add") : _("Done");
      // Cast is required because Gtk.Button.set_focus_on_click is deprecated and
      // we have to use Gtk.Widget.set_focus_on_click instead
      ((Widget) this.done_button).set_focus_on_click (true);
    }
    // When selecting or editing, we get special headerbars
    this.titlebar.selection_mode = this.state == UiState.SELECTING || this.state.editing ();
  }

  [GtkCallback]
  private void on_back_clicked () {
    show_list_pane ();
  }

  [GtkCallback]
  private void on_edit_button_clicked () {
    if (this.contact_pane.contact == null)
      return;

    this.state = UiState.UPDATING;

    var name = this.contact_pane.contact.individual.display_name;
    this.right_header.title = _("Editing %s").printf (name);
    this.contact_pane.start_editing ();
  }

  [GtkCallback]
  private void on_favorite_button_toggled (ToggleButton button) {
    // Don't change the contact being favorite while switching between the two of them
    if (this.ignore_favorite_button_toggled)
      return;

    var is_fav = this.contact_pane.contact.individual.is_favourite;
    this.contact_pane.contact.individual.is_favourite = !is_fav;
  }

  private void stop_editing (bool drop_changes = false) {
    if (this.state == UiState.CREATING) {
      show_list_pane ();

      if (drop_changes) {
        this.contact_pane.stop_editing (drop_changes);
      } else {
        this.contact_pane.create_contact.begin ();
      }
      this.state = UiState.NORMAL;
    } else {
      show_contact_pane ();
      this.contact_pane.stop_editing (drop_changes);
      this.state = UiState.SHOWING;
    }

    if (this.contact_pane.contact != null) {
      this.right_header.title = this.contact_pane.contact.individual.display_name;
    } else {
      this.right_header.title = "";
    }
  }

  public void add_notification (InAppNotification notification) {
    this.notification_overlay.add_overlay (notification);
    notification.show ();
  }

  public void set_shown_contact (Contact? c) {
    /* FIXME: ask the user to leave edit-mode and act accordingly */
    if (this.contact_pane.on_edit_mode)
      stop_editing ();

    this.contact_pane.show_contact (c);
    if (list_pane != null)
      list_pane.select_contact (c);

    // clearing right_header
    if (c != null) {
      this.ignore_favorite_button_toggled = true;
      this.favorite_button.active = c.individual.is_favourite;
      this.ignore_favorite_button_toggled = false;
      this.favorite_button.tooltip_text = (c.individual.is_favourite)? _("Unmark as favorite")
                                                                     : _("Mark as favorite");
      this.right_header.title = c.individual.display_name;
    }
  }

  [GtkCallback]
  public void new_contact () {
    if (this.state == UiState.UPDATING || this.state == UiState.CREATING)
      return;

    this.list_pane.select_contact (null);

    this.state = UiState.CREATING;

    this.right_header.title = _("New Contact");

    this.contact_pane.new_contact ();
    show_contact_pane ();
  }

  [GtkCallback]
  private void on_cancel_visible () {
    update ();
  }

  [GtkCallback]
  private void on_fold () {
    update ();
  }

  [GtkCallback]
  private void on_child_transition_running () {
    if (!content_box.child_transition_running && content_box.visible_child_name == "list-pane")
      this.list_pane.select_contact (null);
  }

  private void update () {
    left_header.show_close_button = this.content_box.fold == Fold.UNFOLDED || header.visible_child == left_header;
    right_header.show_close_button = this.content_box.fold == Fold.UNFOLDED || header.visible_child == right_header;
    back_revealer.reveal_child = back_revealer.visible = this.content_box.fold == Fold.FOLDED && !this.cancel_button.visible && header.visible_child == right_header;
  }

  private void show_list_pane () {
    content_box.visible_child_name = "list-pane";
    update ();
  }

  private void show_contact_pane () {
    content_box.visible_child_name = "contact-pane";
    update ();
  }

  public void show_search (string query) {
    list_pane.filter_entry.set_text (query);
  }

  private void connect_button_signals () {
    this.select_cancel_button.clicked.connect (() => { this.state = UiState.NORMAL; });
    this.done_button.clicked.connect (() => stop_editing ());
    this.cancel_button.clicked.connect (() => stop_editing (true));
  }

  [GtkCallback]
  bool key_press_event_cb (Gdk.EventKey event) {
    if ((event.keyval == Gdk.keyval_from_name ("q")) &&
        ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)) {
      // Clear the contacts so any changed information is stored
      this.contact_pane.show_contact (null);
      destroy ();
    } else if (((event.keyval == Gdk.Key.s) ||
                (event.keyval == Gdk.Key.f)) &&
               ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)) {
      Utils.grab_entry_focus_no_select (list_pane.filter_entry);
    } else if (event.length >= 1 &&
               Gdk.keyval_to_unicode (event.keyval) != 0 &&
               (event.state & Gdk.ModifierType.CONTROL_MASK) == 0 &&
               (event.state & Gdk.ModifierType.MOD1_MASK) == 0 &&
               (event.keyval != Gdk.Key.Escape) &&
               (event.keyval != Gdk.Key.Tab) &&
               (event.keyval != Gdk.Key.BackSpace) ) {
      Utils.grab_entry_focus_no_select (list_pane.filter_entry);
      propagate_key_event (event);
    }

    return false;
  }

  [GtkCallback]
  bool delete_event_cb (Gdk.EventAny event) {
    // Clear the contacts so any changed information is stored
    this.contact_pane.show_contact (null);
    return false;
  }

  void list_pane_selection_changed_cb (Contact? new_selection) {
    set_shown_contact (new_selection);
    if (this.state != UiState.SELECTING)
      this.state = UiState.SHOWING;

    if (new_selection != null)
      show_contact_pane ();
  }

  void list_pane_link_contacts_cb (LinkedList<Contact> contact_list) {
    set_shown_contact (null);
    this.state = UiState.NORMAL;

    LinkOperation2 operation = null;
    link_contacts_list.begin (contact_list, this.store, (obj, result) => {
        operation = link_contacts_list.end (result);
      });

    string msg = ngettext ("%d contacts linked",
                           "%d contacts linked",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.with_mnemonic (_("_Undo"));

    var notification = new InAppNotification (msg);
    /* signal handlers */
    b.clicked.connect ( () => {
        /* here, we will unlink the thing in question */
        operation.undo.begin ();
        notification.dismiss ();
      });

    add_notification (notification);
  }

  private void delete_contacts (Gee.List<Contact> contacts) {
    set_shown_contact (null);
    this.state = UiState.NORMAL;

    string msg;
    if (contacts.size == 1)
      msg = _("Deleted contact %s").printf (contacts[0].individual.display_name);
    else
      msg = ngettext ("%d contact deleted", "%d contacts deleted", contacts.size)
              .printf (contacts.size);

    var b = new Button.with_mnemonic (_("_Undo"));

    var notification = new InAppNotification (msg, b);

    // Don't wrap (default), but ellipsize
    notification.message_label.wrap = false;
    notification.message_label.max_width_chars = 45;
    notification.message_label.ellipsize = Pango.EllipsizeMode.END;

    // signal handlers
    bool really_delete = true;
    b.clicked.connect ( () => {
        really_delete = false;
        notification.dismiss ();

        foreach (var c in contacts)
          c.hidden = false;

        set_shown_contact (contacts[0]);
        this.state = UiState.SHOWING;
      });
    notification.dismissed.connect ( () => {
        if (really_delete)
          foreach (var c in contacts)
            c.remove_personas.begin ();
      });

    add_notification (notification);
  }

  void contact_pane_contacts_linked_cb (string? main_contact, string linked_contact, LinkOperation operation) {
    string msg;
    if (main_contact != null)
      msg = _("%s linked to %s").printf (main_contact, linked_contact);
    else
      msg = _("%s linked to the contact").printf (linked_contact);

    var b = new Button.with_mnemonic (_("_Undo"));
    var notification = new InAppNotification (msg, b);

    b.clicked.connect ( () => {
        notification.dismiss ();
        operation.undo.begin ();
      });

    add_notification (notification);
  }

  private void bind_dimension_properties_to_settings () {
    this.settings.bind_default (Settings.WINDOW_WIDTH_KEY, this, WINDOW_WIDTH_PROP);
    this.settings.bind_default (Settings.WINDOW_HEIGHT_KEY, this, WINDOW_HEIGHT_PROP);
    this.settings.bind_default (Settings.WINDOW_MAXIMIZED_KEY, this, WINDOW_MAXIMIZED_PROP);
  }
}
