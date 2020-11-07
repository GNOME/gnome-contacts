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

using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-window.ui")]
public class Contacts.Window : Hdy.ApplicationWindow {

  private const GLib.ActionEntry[] action_entries = {
    { "edit-contact",     edit_contact     },
    { "share-contact",    share_contact    },
    { "unlink-contact",   unlink_contact   },
    { "delete-contact",   delete_contact   }
  };

  [GtkChild]
  private Hdy.Leaflet header;
  [GtkChild]
  private Hdy.Leaflet content_box;
  [GtkChild]
  private Gtk.Revealer back_revealer;
  [GtkChild]
  private Gtk.Stack list_pane_stack;
  [GtkChild]
  private Gtk.Container contact_pane_container;
  [GtkChild]
  private Hdy.HeaderBar left_header;
  [GtkChild]
  private Gtk.Separator header_separator;
  [GtkChild]
  private Hdy.HeaderBar right_header;
  [GtkChild]
  private Gtk.Overlay notification_overlay;
  [GtkChild]
  private Gtk.Button select_cancel_button;
  [GtkChild]
  private Gtk.MenuButton hamburger_menu_button;
  [GtkChild]
  private Gtk.ModelButton sort_on_firstname_button;
  [GtkChild]
  private Gtk.ModelButton sort_on_surname_button;
  [GtkChild]
  private Gtk.MenuButton contact_menu_button;
  [GtkChild]
  private Gtk.ToggleButton favorite_button;
  private bool ignore_favorite_button_toggled;
  [GtkChild]
  private Gtk.Button unlink_button;
  [GtkChild]
  private Gtk.Button add_button;
  [GtkChild]
  private Gtk.Button cancel_button;
  [GtkChild]
  private Gtk.Button done_button;

  // The 2 panes the window consists of
  private ListPane list_pane;
  private ContactPane contact_pane;

  public UiState state { get; set; default = UiState.NORMAL; }

  /** Holds the current width. */
  public int window_width { get; set; }
  /** Holds the current height. */
  public int window_height { get; set; }
  /** Holds true if the window is currently maximized. */
  public bool window_maximized { get; set; }

  private Settings settings;

  public Store store {
    get; construct set;
  }

  public Window (Settings settings, App app, Store contacts_store) {
    Object (
      application: app,
      show_menubar: false,
      visible: true,
      store: contacts_store
    );

    SimpleActionGroup actions = new SimpleActionGroup ();
    actions.add_action_entries (action_entries, this);
    this.insert_action_group ("window", actions);

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

    if (Config.PROFILE == "development")
        get_style_context ().add_class ("devel");
  }

  private void on_sort_changed () {
    this.sort_on_firstname_button.active = !this.settings.sort_on_surname;
    this.sort_on_surname_button.active = this.settings.sort_on_surname;
  }

  private void restore_window_size_and_position_from_settings () {
    unowned var screen = get_screen ();
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

    unowned var screen = get_screen ();
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
    this.contact_pane.contacts_linked.connect (contact_pane_contacts_linked_cb);
    this.contact_pane.display_name_changed.connect ((display_name) => {
      this.right_header.title = display_name;
    });
    this.contact_pane_container.add (this.contact_pane);
  }

  /**
   * This shows the contact list on the left. This needs to be called
   * explicitly when contacts are loaded, as the original setup will
   * only show a loading spinner.
   */
  public void show_contact_list () {
    // FIXME: if no contact is loaded per backend, I must place a sign
    // saying "import your contacts/add online account"
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

    if (this.contact_pane.individual != null)
      list_pane.select_contact (this.contact_pane.individual);

  }

  private void on_ui_state_changed (Object obj, ParamSpec pspec) {
    // UI when we're not editing of selecting stuff
    this.add_button.visible
        = this.hamburger_menu_button.visible
        = (this.state == UiState.NORMAL || this.state == UiState.SHOWING);

    // UI when showing a contact
    this.contact_menu_button.visible
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
      ((Gtk.Widget) this.done_button).set_focus_on_click (true);
    }
    // When selecting or editing, we get special headerbars
    set_selection_mode (this.state == UiState.SELECTING || this.state.editing ());

    // Allow the back gesture when not browsing
    this.content_box.can_swipe_back = this.state == UiState.NORMAL ||
                                      this.state == UiState.SHOWING ||
                                      this.state == UiState.SELECTING;
  }

  private void set_selection_mode (bool selection_mode) {
    unowned var left_ctx = this.left_header.get_style_context ();
    unowned var separator_ctx = this.header_separator.get_style_context ();
    unowned var right_ctx = this.right_header.get_style_context ();
    if (selection_mode) {
      left_ctx.add_class ("selection-mode");
      separator_ctx.add_class ("selection-mode");
      right_ctx.add_class ("selection-mode");
    } else {
      left_ctx.remove_class ("selection-mode");
      separator_ctx.remove_class ("selection-mode");
      right_ctx.remove_class ("selection-mode");
    }
  }

  [GtkCallback]
  private void on_back_clicked () {
    show_list_pane ();
  }

  private void share_contact () {
    debug ("Share isn't implemented, yet");
  }

  private void edit_contact () {
    if (this.contact_pane.individual == null)
      return;

    this.state = UiState.UPDATING;

    unowned var name = this.contact_pane.individual.display_name;
    this.right_header.title = _("Editing %s").printf (name);
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

  private void unlink_contact () {
    var individual = this.contact_pane.individual;
    if (individual == null)
      return;

    set_shown_contact (null);
    this.state = UiState.NORMAL;

    var operation = new UnLinkOperation (this.store);
    operation.do.begin (individual);

    var b = new Gtk.Button.with_mnemonic (_("_Undo"));
    var notification = new InAppNotification (_("Contacts unlinked"), b);

    /* signal handlers */
    b.clicked.connect ( () => {
        /* here, we will link the thing in question */
        operation.undo.begin ();
        notification.dismiss ();
      });

    add_notification (notification);
  }

  private void delete_contact () {
    var individual = this.contact_pane.individual;
    if (individual == null)
      return;

    this.list_pane.hide_contact (individual);
    delete_contacts (new Gee.ArrayList<Individual>.wrap ({ individual }));
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

    if (this.contact_pane.individual != null) {
      this.right_header.title = this.contact_pane.individual.display_name;
    } else {
      this.right_header.title = "";
    }
  }

  public void add_notification (InAppNotification notification) {
    this.notification_overlay.add_overlay (notification);
    notification.show ();
  }

  public void set_shown_contact (Individual? i) {
    /* FIXME: ask the user to leave edit-mode and act accordingly */
    if (this.contact_pane.on_edit_mode)
      stop_editing ();

    this.contact_pane.show_contact (i);
    if (list_pane != null)
      list_pane.select_contact (i);

    // clearing right_header
    if (i != null) {
      this.ignore_favorite_button_toggled = true;
      this.favorite_button.active = i.is_favourite;
      this.ignore_favorite_button_toggled = false;
      this.favorite_button.tooltip_text = (i.is_favourite)? _("Unmark as favorite")
                                                                     : _("Mark as favorite");
      this.right_header.title = i.display_name;
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
    update_header ();
  }

  [GtkCallback]
  private void on_folded () {
    update_header ();
  }

  [GtkCallback]
  private void on_child_transition_running () {
    if (!content_box.child_transition_running && content_box.visible_child_name == "list-pane")
      this.list_pane.select_contact (null);
  }

  private void update_header () {
    this.back_revealer.reveal_child =
      this.back_revealer.visible =
        this.content_box.folded &&
        !this.cancel_button.visible &&
        this.header.visible_child == this.right_header;
  }

  private void show_list_pane () {
    content_box.visible_child_name = "list-pane";
    update_header ();
  }

  private void show_contact_pane () {
    content_box.visible_child_name = "contact-pane";
    update_header ();
  }

  public void show_search (string query) {
    list_pane.filter_entry.set_text (query);
  }

  private void connect_button_signals () {
    this.select_cancel_button.clicked.connect (() => { this.state = UiState.NORMAL; });
    this.done_button.clicked.connect (() => stop_editing ());
    this.cancel_button.clicked.connect (() => stop_editing (true));

    this.contact_pane.notify["individual"].connect (() => {
      unowned var individual = this.contact_pane.individual;
      if (individual == null)
        return;
      this.unlink_button.set_visible (individual.personas.size > 1);
    });
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

  void list_pane_selection_changed_cb (Individual? new_selection) {
    set_shown_contact (new_selection);
    if (this.state != UiState.SELECTING)
      this.state = UiState.SHOWING;

    if (new_selection != null)
      show_contact_pane ();
  }

  void list_pane_link_contacts_cb (Gee.LinkedList<Individual> contact_list) {
    set_shown_contact (null);
    this.state = UiState.NORMAL;

    var operation = new LinkOperation (this.store);
    operation.do.begin (contact_list);

    string msg = ngettext ("%d contacts linked",
                           "%d contacts linked",
                           contact_list.size).printf (contact_list.size);

    var b = new Gtk.Button.with_mnemonic (_("_Undo"));
    var notification = new InAppNotification (msg, b);

    /* signal handlers */
    b.clicked.connect ( () => {
        /* here, we will unlink the thing in question */
        operation.undo.begin ();
        notification.dismiss ();
      });

    add_notification (notification);
  }

  private void delete_contacts (Gee.List<Individual> individuals) {
    set_shown_contact (null);
    this.state = UiState.NORMAL;

    string msg;
    if (individuals.size == 1)
      msg = _("Deleted contact %s").printf (individuals[0].display_name);
    else
      msg = ngettext ("%d contact deleted", "%d contacts deleted", individuals.size)
              .printf (individuals.size);

    var b = new Gtk.Button.with_mnemonic (_("_Undo"));

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

        /* Reset the contact list */
        list_pane.undo_deletion ();

        set_shown_contact (individuals[0]);
        this.state = UiState.SHOWING;
      });
    notification.dismissed.connect ( () => {
        if (really_delete)
          foreach (var i in individuals)
            foreach (var p in i.personas) {
              // TODO: make sure it is acctally removed
              p.store.remove_persona.begin (p, (obj, res) => {
                try {
                  p.store.remove_persona.end (res);
                } catch (Error e) {
                  debug ("Coudln't remove persona: %s", e.message);
                }
              });
            }
      });

    add_notification (notification);
  }

  void contact_pane_contacts_linked_cb (string? main_contact, string linked_contact, LinkOperation operation) {
    string msg;
    if (main_contact != null)
      msg = _("%s linked to %s").printf (main_contact, linked_contact);
    else
      msg = _("%s linked to the contact").printf (linked_contact);

    var b = new Gtk.Button.with_mnemonic (_("_Undo"));
    var notification = new InAppNotification (msg, b);

    b.clicked.connect ( () => {
        notification.dismiss ();
        operation.undo.begin ();
      });

    add_notification (notification);
  }

  private void bind_dimension_properties_to_settings () {
    this.settings.bind_default (Settings.WINDOW_WIDTH_KEY, this, "window-width");
    this.settings.bind_default (Settings.WINDOW_HEIGHT_KEY, this, "window-height");
    this.settings.bind_default (Settings.WINDOW_MAXIMIZED_KEY, this, "window-maximized");
  }
}
