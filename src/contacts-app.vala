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

using Gtk;
using Folks;

public class Contacts.App : Gtk.Application {
  public Contacts.Window window;
  public static App app;
  public Store contacts_store;
  private ListPane list_pane;
  private ContactPane contacts_pane;
  private Gtk.Overlay overlay;

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
      list_pane.set_search_visible (true);
    } else if (event.length >= 1 &&
	       Gdk.keyval_to_unicode (event.keyval) != 0 &&
	       (event.state & Gdk.ModifierType.CONTROL_MASK) == 0 &&
	       (event.state & Gdk.ModifierType.MOD1_MASK) == 0 &&
	       (event.keyval != Gdk.Key.Escape) &&
	       (event.keyval != Gdk.Key.Tab) &&
	       (event.keyval != Gdk.Key.BackSpace) ) {
      list_pane.set_search_visible (true);
      window.propagate_key_event (event);
    }

    return false;
  }

  private void selection_changed (Contact? new_selection) {
    contacts_pane.show_contact (new_selection);
  }

  public void show_contact (Contact? contact) {
    list_pane.select_contact (contact);
    contacts_pane.show_contact (contact);
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

    foreach (var persona_store in Contact.get_eds_address_books ()) {
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

	    try {
	      E.BookClient.set_default_source (e_store.source);
	    } catch {
	      warning ("Failed to set address book");
	    }

	    contacts_store.refresh ();
	  }
	}
	dialog.destroy ();
      });
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
			   "logo-icon-name", "avatar-default",
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
    this.app = this;

    var action = new GLib.SimpleAction ("quit", null);
    action.activate.connect (() => { window.destroy (); });
    this.add_action (action);

    action = new GLib.SimpleAction ("about", null);
    action.activate.connect (() => { show_about (); });
    this.add_action (action);

    action = new GLib.SimpleAction ("change_book", null);
    action.activate.connect (() => { change_address_book (); });
    this.add_action (action);

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
    window.set_default_size (888, 600);
    window.hide_titlebar_when_maximized = true;
    window.delete_event.connect (window_delete_event);
    window.key_press_event.connect_after (window_key_press_event);

    var grid = new Grid();

    var toolbar = new Toolbar ();
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.get_style_context ().add_class (STYLE_CLASS_MENUBAR);
    toolbar.get_style_context ().add_class ("contacts-left-toolbar");
    toolbar.set_vexpand (false);
    toolbar.set_hexpand (false);
    grid.attach (toolbar, 0, 0, 1, 1);

    var add_button = new ToolButton (null, _("Add..."));
    add_button.margin_left = 4;
    add_button.is_important = true;
    toolbar.add (add_button);
    add_button.clicked.connect ( (button) => {
	var dialog = new NewContactDialog (contacts_store, window);
	dialog.show_all ();
      });

    toolbar = new Toolbar ();
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.get_style_context ().add_class (STYLE_CLASS_MENUBAR);
    toolbar.set_vexpand (false);
    toolbar.set_hexpand (true);
    grid.attach (toolbar, 1, 0, 1, 1);

    var share_button = new ToolButton (null, null);
    share_button.set_sensitive (false);
    share_button.margin_right = 4;
    share_button.set_icon_name ("send-to-symbolic");
    share_button.is_important = false;
    share_button.set_halign (Align.END);
    share_button.set_expand (true);
    toolbar.add (share_button);
    share_button.clicked.connect ( (button) => {
      });

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

    grid.attach (list_pane, 0, 1, 1, 1);

    contacts_pane = new ContactPane (contacts_store);
    contacts_pane.set_hexpand (true);
    contacts_pane.will_delete.connect (delete_contact);
    grid.attach (contacts_pane, 1, 1, 1, 1);


    grid.show_all ();
  }

  public override void startup () {
    ensure_eds_accounts ();
    contacts_store = new Store ();
    base.startup ();
  }

  public override void activate () {
    if (window == null) {
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

  private void delete_contact (Contact contact) {
    var notification = new Gtk.Notification ();

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg = _("Contact deleted: \"%s\"").printf (contact.display_name);
    var b = new Button.from_stock (Stock.UNDO);
    g.add (new Label (msg));
    g.add (b);

    bool really_delete = true;
    notification.show_all ();
    var id = notification.dismissed.connect ( () => {
	if (really_delete)
	  contact.remove_personas.begin ( () => {
	      contact.show ();
	    });
      });
    b.clicked.connect ( () => {
	really_delete = false;
	notification.dismiss ();
	contact.show ();
	list_pane.select_contact (contact);
	contacts_pane.show_contact (contact);
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

  public App () {
    Object (application_id: "org.gnome.Contacts", flags: ApplicationFlags.HANDLES_COMMAND_LINE);
  }
}
