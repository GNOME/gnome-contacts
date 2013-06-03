/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
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
using Folks;

public class Contacts.App : Gtk.Application {
  public static App app;
  public GLib.Settings settings;
  public Store contacts_store;

  public Contacts.Window window;
  private Gtk.Overlay overlay;

  private Gd.MainToolbar left_toolbar;
  private ToggleButton select_button;
  private ListPane list_pane;

  private Toolbar right_toolbar;
  private Label contact_name;
  private Button edit_button;
  private Button done_button;

  private ContactPane contacts_pane;
  private Overlay right_overlay;

  private bool window_delete_event (Gdk.EventAny event) {
    // Clear the contacts so any changed information is stored
    contacts_pane.show_contact (null);
    return false;
  }

  private bool window_key_press_event (Gdk.EventKey event) {
    if ((event.keyval == Gdk.keyval_from_name ("q")) &&
        ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)) {
      // Clear the contacts so any changed information is stored
      contacts_pane.show_contact (null);
      window.destroy ();
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
      window.propagate_key_event (event);
    }

    return false;
  }

  private void selection_changed (Contact? new_selection) {
    /* FIXME: ask the user lo teave edit-mode and act accordingly */
    if (contacts_pane.on_edit_mode) {
      contacts_pane.set_edit_mode (false);

      contact_name.set_text (null);
      done_button.hide ();
    }

    contacts_pane.show_contact (new_selection, false, false);

    /* clearing right_toolbar */
    if (new_selection != null) {
      edit_button.show ();
    } else {
      edit_button.hide ();
    }
  }

  public void show_contact (Contact? contact) {
    list_pane.select_contact (contact);

    /* hack for showing contact */
    selection_changed (contact);
  }

  public async void show_individual (string id) {
    var contact = yield contacts_store.find_contact ( (c) => {
        return c.individual.id == id;
      });
    if (contact != null) {
      list_pane.select_contact (contact);
      contacts_pane.show_contact (contact);
    } else {
      var dialog = new MessageDialog (App.app.window, DialogFlags.DESTROY_WITH_PARENT, MessageType.ERROR, ButtonsType.CLOSE,
                                      _("No contact with id %s found"), id);
      dialog.set_title(_("Contact not found"));
      dialog.show ();
      dialog.response.connect ( (id) => {
          dialog.destroy ();
        });
    }
  }

  public void change_address_book () {
    var title = _("Change Address Book");
    var dialog = new Dialog.with_buttons ("",
                                          (Window) window,
                                          DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                          Stock.CANCEL, ResponseType.CANCEL,
                                          _("Select"), ResponseType.OK);

    dialog.set_resizable (false);
    dialog.set_default_response (ResponseType.OK);

    var tree_view = new TreeView ();
    var store = new ListStore (2, typeof (string), typeof (Folks.PersonaStore));
    tree_view.set_model (store);
    tree_view.set_headers_visible (false);
    tree_view.get_selection ().set_mode (SelectionMode.BROWSE);

    var column = new Gtk.TreeViewColumn ();
    tree_view.append_column (column);

    var renderer = new Gtk.CellRendererText ();
    column.pack_start (renderer, false);
    column.add_attribute (renderer, "text", 0);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_size_request (340, 300);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_shadow_type (ShadowType.IN);
    scrolled.add (tree_view);

    var grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_row_spacing (6);

    var l = new Label (title);
    l.set_halign (Align.START);

    grid.add (l);
    grid.add (scrolled);

    var box = dialog.get_content_area () as Box;
    box.pack_start (grid, true, true, 0);
    grid.set_border_width (6);

    TreeIter iter;

    foreach (var persona_store in get_eds_address_books ()) {
      var name = Contact.format_persona_store_name (persona_store);
      store.append (out iter);
      store.set (iter, 0, name, 1, persona_store);
      if (persona_store == contacts_store.aggregator.primary_store) {
        tree_view.get_selection ().select_iter (iter);
      }
    }

    dialog.show_all ();
    dialog.response.connect ( (response) => {
        if (response == ResponseType.OK) {
          PersonaStore selected_store;
          TreeIter iter2;

          if (tree_view.get_selection() .get_selected (null, out iter2)) {
            store.get (iter2, 1, out selected_store);

            var e_store = selected_store as Edsf.PersonaStore;

            eds_source_registry.set_default_address_book (e_store.source);

            contacts_store.refresh ();
          }
        }
        dialog.destroy ();
      });
  }

  public void show_help () {
    Gtk.show_uri (window.get_screen (),
         "help:gnome-help/contacts",
         Gtk.get_current_event_time ());
  }

  public void show_about () {
    string[] authors = {
      "Alexander Larsson <alexl@redhat.com>",
      "Erick Pérez Castellanos <erick.red@gmail.com>"
    };
    string[] artists = {
      "Allan Day <allanpday@gmail.com>"
    };
    Gtk.show_about_dialog (window,
                           "artists", artists,
                           "authors", authors,
                           "translator-credits", _("translator-credits"),
                           "program-name", _("GNOME Contacts"),
                           "title", _("About GNOME Contacts"),
                           "comments", _("Contact Management Application"),
                           "copyright", "Copyright 2011 Red Hat, Inc.",
                           "license-type", Gtk.License.GPL_2_0,
                           "logo-icon-name", "x-office-address-book",
                           "version", Config.PACKAGE_VERSION,
                           "website", "https://live.gnome.org/Contacts",
                           "wrap-license", true);
  }

  public async void show_by_email (string email_address) {
    var contact = yield contacts_store.find_contact ( (c) => {
        return c.has_email (email_address);
      });
    if (contact != null) {
      list_pane.select_contact (contact);
      contacts_pane.show_contact (contact);
    } else {
      var dialog = new MessageDialog (App.app.window, DialogFlags.DESTROY_WITH_PARENT, MessageType.ERROR, ButtonsType.CLOSE,
                                      _("No contact with email address %s found"), email_address);
      dialog.set_title(_("Contact not found"));
      dialog.show ();
      dialog.response.connect ( (id) => {
          dialog.destroy ();
        });
    }
  }

  private void create_window () {
    var action = new GLib.SimpleAction ("quit", null);
    action.activate.connect (() => { window.destroy (); });
    this.add_action (action);

    action = new GLib.SimpleAction ("help", null);
    action.activate.connect (() => { show_help (); });
    this.add_action (action);
    this.add_accelerator ("F1", "app.help", null);

    action = new GLib.SimpleAction ("about", null);
    action.activate.connect (() => { show_about (); });
    this.add_action (action);

    action = new GLib.SimpleAction ("change_book", null);
    action.activate.connect (() => { change_address_book (); });
    this.add_action (action);

    action = new GLib.SimpleAction ("new_contact", null);
    action.activate.connect (() => { new_contact (); });
    this.add_action (action);
    this.add_accelerator ("<Primary>n", "app.new_contact", null);

    var view_action = new GLib.SimpleAction.stateful ("view_subset", VariantType.STRING, settings.get_value ("view-subset"));
    this.add_action (view_action);
    settings.changed["view-subset"].connect (() => {
        view_action.set_state (settings.get_value ("view-subset"));
        list_pane.refilter ();
      });
    view_action.activate.connect ((act, parameter) => {
        settings.set_value ("view-subset", parameter);
      });

    var builder = new Builder ();
    builder.set_translation_domain (Config.GETTEXT_PACKAGE);
    try {
      Gtk.my_builder_add_from_resource (builder, "/org/gnome/contacts/app-menu.ui");
      set_app_menu ((MenuModel)builder.get_object ("app-menu"));
    } catch {
      warning ("Failed to parsing ui file");
    }

    window = new Contacts.Window (this);
    window.set_application (this);
    window.set_title (_("Contacts"));
    window.set_default_size (800, 600);
    window.hide_titlebar_when_maximized = true;
    window.delete_event.connect (window_delete_event);
    window.key_press_event.connect_after (window_key_press_event);

    var grid = new Grid();

    left_toolbar = new Gd.MainToolbar ();
    left_toolbar.get_style_context ().add_class (STYLE_CLASS_MENUBAR);
    left_toolbar.get_style_context ().add_class ("contacts-left-toolbar");
    left_toolbar.set_vexpand (false);
    grid.attach (left_toolbar, 0, 0, 1, 1);

    var add_button = left_toolbar.add_button (null, _("New"), true) as Gtk.Button;
    add_button.set_size_request (70, -1);
    add_button.set_vexpand (true);
    add_button.clicked.connect (app.new_contact);

    select_button = left_toolbar.add_toggle ("object-select-symbolic", null, false) as ToggleButton;

    right_toolbar = new Toolbar ();
    right_toolbar.get_style_context ().add_class (STYLE_CLASS_MENUBAR);
    right_toolbar.set_vexpand (false);
    grid.attach (right_toolbar, 1, 0, 1, 1);

    contact_name = new Label (null);
    contact_name.set_ellipsize (Pango.EllipsizeMode.END);
    contact_name.wrap_mode = Pango.WrapMode.CHAR;
    contact_name.set_halign (Align.START);
    contact_name.set_valign (Align.CENTER);
    contact_name.set_vexpand (true);
    contact_name.set_hexpand (true);
    contact_name.margin_left = 12;
    contact_name.margin_right = 12;
    var item = new ToolItem ();
    item.set_expand (true);
    item.add (contact_name);
    right_toolbar.insert (item, -1);

    /* spacer */
    item = new SeparatorToolItem ();
    (item as SeparatorToolItem).set_draw (false);
    (item as ToolItem).set_expand (true);
    right_toolbar.insert (item, -1);

    edit_button = new Button.with_label (_("Edit"));
    edit_button.set_size_request (70, -1);
    item = new ToolItem ();
    item.add (edit_button);
    right_toolbar.insert (item, -1);

    done_button = new Button.with_label (_("Done"));
    done_button.set_size_request (70, -1);
    done_button.get_style_context ().add_class ("suggested-action");
    item = new ToolItem ();
    item.add (done_button);
    right_toolbar.insert (item, -1);

    window.add (grid);

    /* We put in an overlay overlapping the left and right pane for the
       notifications, so they can show up below the toolbar */
    overlay = new Gtk.Overlay ();
    Gdk.RGBA transparent = { 0, 0, 0, 0 };
    overlay.override_background_color (0, transparent);
    // Need to put something in here for it to work
    overlay.add (new Alignment (0,0,0,0));
    grid.attach (overlay, 0, 1, 2, 1);

    list_pane = new ListPane (contacts_store);
    list_pane.selection_changed.connect (selection_changed);
    list_pane.link_contacts.connect (link_contacts);
    list_pane.delete_contacts.connect (delete_contacts);

    grid.attach (list_pane, 0, 1, 1, 1);

    contacts_pane = new ContactPane (contacts_store);
    contacts_pane.set_hexpand (true);
    contacts_pane.will_delete.connect (delete_contact);
    contacts_pane.contacts_linked.connect (contacts_linked);

    right_overlay = new Overlay ();
    right_overlay.override_background_color (0, transparent);
    right_overlay.add (contacts_pane);

    grid.attach (right_overlay, 1, 1, 1, 1);

    grid.show_all ();

    select_button.toggled.connect (() => {
        if (select_button.active)
          list_pane.show_selection ();
        else
          list_pane.hide_selection ();
      });

    edit_button.clicked.connect (() => {
        if (select_button.active)
          select_button.set_active (false);

        var name = _("Editing");
        if (contacts_pane.contact != null) {
          name += " %s".printf (contacts_pane.contact.display_name);
        }

        contact_name.set_markup (Markup.printf_escaped ("<b>%s</b>", name));
        edit_button.hide ();
        done_button.show ();
        contacts_pane.set_edit_mode (true);
      });

    done_button.clicked.connect (() => {
        contact_name.set_text (null);
        done_button.hide ();
        edit_button.show ();
        contacts_pane.set_edit_mode (false);
      });

    edit_button.hide ();
    done_button.hide ();
  }

  public override void startup () {
    ensure_eds_accounts ();
    contacts_store = new Store ();
    base.startup ();
  }

  private void show_setup () {
    var setup = new SetupWindow ();
    setup.set_application (this);
    setup.destroy.connect ( () => {
        setup.destroy ();
        if (setup.succeeded)
          this.activate ();
      });
    setup.show ();
  }

  public override void activate () {
    if (window == null) {
      if (!settings.get_boolean ("did-initial-setup")) {
        if (contacts_store.is_prepared)
          show_setup ();
        else {
          hold ();
          ulong id = 0;
          uint id2 = 0;
          id = contacts_store.prepared.connect (() => {
              show_setup ();
              contacts_store.disconnect (id);
              Source.remove (id2);
              release ();
            });
          // Wait at most 0.5 seconds to show the window
          id2 = Timeout.add (500, () => {
              show_setup ();
              contacts_store.disconnect (id);
              release ();
              return false;
        });
        }

        return;
      }

      create_window ();

      // We delay the initial show a tiny bit so most contacts are loaded when we show
      contacts_store.quiescent.connect (() => {
          app.window.show ();
        });
      // Wait at most 0.5 seconds to show the window
      Timeout.add (500, () => {
          app.window.show ();
          return false;
        });
    } else {
      window.present ();
    }
  }

  public void show_message (string message) {
    var notification = new Gd.Notification ();

    var g = new Grid ();
    g.set_column_spacing (8);
    var l = new Label (message);
    l.set_line_wrap (true);
    l.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    notification.add (l);

    notification.show_all ();
    overlay.add_overlay (notification);
  }

  public void new_contact () {
    var dialog = new NewContactDialog (contacts_store, window);
    dialog.show_all ();
  }

  private void link_contacts (LinkedList<Contact> contact_list) {
    /* getting out of selection mode */
    show_contact (null);
    select_button.set_active (false);

    LinkOperation2 operation = null;
    link_contacts_list.begin (contact_list, (obj, result) => {
        operation = link_contacts_list.end (result);
      });

    var notification = new Gd.Notification ();

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg = ngettext ("%d contacts linked",
                           "%d contacts linked",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.from_stock (Stock.UNDO);
    g.add (new Label (msg));
    g.add (b);

    notification.show_all ();
    overlay.add_overlay (notification);

    /* signal handlers */
    b.clicked.connect ( () => {
        /* here, we will unlink the thing in question */
        operation.undo.begin ();

        notification.dismiss ();
      });
  }

  private void delete_contacts (LinkedList<Contact> contact_list) {
    /* getting out of selection mode */
    show_contact (null);
    select_button.set_active (false);

    var notification = new Gd.Notification ();

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg = ngettext ("%d contact deleted",
                           "%d contacts deleted",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.from_stock (Stock.UNDO);
    g.add (new Label (msg));
    g.add (b);

    notification.show_all ();
    overlay.add_overlay (notification);

    /* signal handlers */
    bool really_delete = true;
    notification.dismissed.connect ( () => {
        if (really_delete) {
          foreach (var c in contact_list) {
            c.remove_personas.begin ();
          }
        }
      });
    b.clicked.connect ( () => {
        really_delete = false;
        notification.dismiss ();
          foreach (var c in contact_list) {
            c.show ();
          }
      });
  }

  private void delete_contact (Contact contact) {
    /* unsetting edit-mode */
    contact_name.set_text (null);
    done_button.hide ();
    contacts_pane.set_edit_mode (false);

    var notification = new Gd.Notification ();

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg = _("Contact deleted: \"%s\"").printf (contact.display_name);
    var b = new Button.from_stock (Stock.UNDO);
    g.add (new Label (msg));
    g.add (b);

    bool really_delete = true;
    notification.show_all ();
    notification.dismissed.connect ( () => {
        if (really_delete)
          contact.remove_personas.begin ( () => {
              contact.show ();
            });
      });
    b.clicked.connect ( () => {
        really_delete = false;
        notification.dismiss ();
        contact.show ();
        show_contact (contact);
      });
    overlay.add_overlay (notification);
  }

  private static string individual_id = null;
  private static string email_address = null;
  private static const OptionEntry[] options = {
    { "individual", 'i', 0, OptionArg.STRING, ref individual_id,
      N_("Show contact with this individual id"), null },
    { "email", 'e', 0, OptionArg.STRING, ref email_address,
      N_("Show contact with this email address"), null },
    { null }
  };

  private void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation) {
    var notification = new Gd.Notification ();

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg;
    if (main_contact != null)
      msg = _("%s linked to %s").printf (main_contact, linked_contact);
    else
      msg = _("%s linked to the contact").printf (linked_contact);

    var b = new Button.from_stock (Stock.UNDO);
    g.add (new Label (msg));
    g.add (b);

    notification.show_all ();
    b.clicked.connect ( () => {
      notification.dismiss ();
      operation.undo.begin ();
    });
    overlay.add_overlay (notification);
  }

  public override int command_line (ApplicationCommandLine command_line) {
    var args = command_line.get_arguments ();
    unowned string[] _args = args;
    var context = new OptionContext (N_("— contact management"));
    context.add_main_entries (options, Config.GETTEXT_PACKAGE);
    context.set_translation_domain (Config.GETTEXT_PACKAGE);
    context.add_group (Gtk.get_option_group (true));

    individual_id = null;
    email_address = null;

    try {
      context.parse (ref _args);
    } catch (Error e) {
      printerr ("Unable to parse: %s\n", e.message);
      return 1;
    }

    activate ();

    if (individual_id != null)
      app.show_individual.begin (individual_id);
    if (email_address != null)
      app.show_by_email.begin (email_address);

    return 0;
  }

  public static PersonaStore[] get_eds_address_books () {
    PersonaStore[] stores = {};
    foreach (var backend in app.contacts_store.backend_store.enabled_backends.values) {
      foreach (var persona_store in backend.persona_stores.values) {
        if (persona_store.type_id == "eds") {
          stores += persona_store;
        }
      }
    }
    return stores;
  }

  public App () {
    Object (application_id: "org.gnome.Contacts", flags: ApplicationFlags.HANDLES_COMMAND_LINE);
    app = this;
    settings = new GLib.Settings ("org.gnome.Contacts");
  }
}
