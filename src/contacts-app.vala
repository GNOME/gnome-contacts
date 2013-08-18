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

  private ListPane list_pane;
  private ContactPane contacts_pane;

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

      window.right_title = "";
      window.done_button.hide ();
    }

    contacts_pane.show_contact (new_selection, false, false);

    /* clearing right_toolbar */
    if (new_selection != null) {
      window.right_title = new_selection.display_name;
      window.edit_button.show ();
    } else {
      window.edit_button.hide ();
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
      show_contact (contact);
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
    var dialog = new Dialog.with_buttons ("",
					  (Window) window,
					  DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
					  null);
    dialog.set_resizable (false);
    dialog.set_border_width (36);

    var header = new HeaderBar ();
    header.set_title (_("Primary Contacts Account"));
    var cancel_button = new Button.with_label (_("Cancel"));
    cancel_button.get_child ().margin = 3;
    cancel_button.get_child ().margin_left = 6;
    cancel_button.get_child ().margin_right = 6;
    cancel_button.clicked.connect (() => {
	dialog.response (ResponseType.CANCEL);
      });
    header.pack_start (cancel_button);

    var done_button = new Button.with_label (_("Done"));
    done_button.get_style_context ().add_class ("suggested-action");
    done_button.get_child ().margin = 3;
    done_button.get_child ().margin_left = 6;
    done_button.get_child ().margin_right = 6;
    done_button.clicked.connect (() => {
	dialog.response (ResponseType.OK);
      });
    header.pack_end (done_button);

    dialog.set_titlebar (header);

    var acc = new AccountsList ();
    acc.update_contents (true);

    ulong stores_changed_id = contacts_store.eds_persona_store_changed.connect  ( () => {
    	acc.update_contents (true);
      });

    (dialog.get_content_area () as Box).add (acc);

    dialog.show_all ();
    dialog.response.connect ( (response) => {
	if (response == ResponseType.OK) {
	  var e_store = acc.selected_store as Edsf.PersonaStore;
	  if (e_store != null) {
	    eds_source_registry.set_default_address_book (e_store.source);
	    contacts_store.refresh ();
	  }
	}
	contacts_store.disconnect (stores_changed_id);
	dialog.destroy ();
      });
  }

  public void show_help () {
    try {
      Gtk.show_uri (window.get_screen (),
           "help:gnome-help/contacts",
           Gtk.get_current_event_time ());
    } catch (GLib.Error e1) {
      warning ("Error showing help: %s", e1.message);
    }
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
                           "copyright", "Copyright 2011 Red Hat, Inc.\nCopyright 2013 The Contacts Developers",
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
      show_contact (contact);
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

    var builder = load_ui ("app-menu.ui");
    set_app_menu ((MenuModel)builder.get_object ("app-menu"));

    window = new Contacts.Window (this);
    window.delete_event.connect (window_delete_event);
    window.key_press_event.connect_after (window_key_press_event);

    list_pane = new ListPane (contacts_store);
    list_pane.selection_changed.connect (selection_changed);
    list_pane.link_contacts.connect (link_contacts);
    list_pane.delete_contacts.connect (delete_contacts);

    window.add_left_child (list_pane);

    contacts_pane = new ContactPane (contacts_store);
    contacts_pane.set_hexpand (true);
    contacts_pane.will_delete.connect (delete_contact);
    contacts_pane.contacts_linked.connect (contacts_linked);

    window.add_right_child (contacts_pane);

    list_pane.contacts_marked.connect ((nr_contacts) => {
	if (nr_contacts == 0)
	  window.left_title = _("Select");
	else
	  window.left_title = _("%d Selected").printf (nr_contacts);
      });

    window.add_button.clicked.connect (app.new_contact);

    window.select_button.toggled.connect (() => {
        if (window.select_button.active) {
	  /* Update UI */
	  window.activate_selection_mode (true);

          list_pane.show_selection ();
	} else {
          list_pane.hide_selection ();

	  /* Update UI */
	  window.activate_selection_mode (false);
	}
      });

    window.edit_button.clicked.connect (() => {
        if (window.select_button.active)
          window.select_button.set_active (false);

        var name = _("Editing");
        if (contacts_pane.contact != null) {
          name += " %s".printf (contacts_pane.contact.display_name);
        }

	window.right_title = name;
        window.edit_button.hide ();
        window.done_button.show ();
        contacts_pane.set_edit_mode (true);
      });

    window.done_button.clicked.connect (() => {
        window.done_button.hide ();
        window.edit_button.show ();
        contacts_pane.set_edit_mode (false);

        if (contacts_pane.contact != null) {
	  window.right_title = contacts_pane.contact.display_name;
        }
      });

    window.show_all ();

    window.edit_button.hide ();
    window.done_button.hide ();
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
    notification.timeout = 5;

    var g = new Grid ();
    g.set_column_spacing (8);
    var l = new Label (message);
    l.set_line_wrap (true);
    l.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    notification.add (l);

    notification.show_all ();
    window.add_notification (notification);
  }

  public void new_contact () {
    var dialog = NewContactDialog.get_default (contacts_store, window);
    dialog.show_all ();
  }

  private void link_contacts (LinkedList<Contact> contact_list) {
    /* getting out of selection mode */
    show_contact (null);
    window.select_button.set_active (false);

    LinkOperation2 operation = null;
    link_contacts_list.begin (contact_list, (obj, result) => {
        operation = link_contacts_list.end (result);
      });

    var notification = new Gd.Notification ();
    notification.timeout = 5;

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg = ngettext ("%d contacts linked",
                           "%d contacts linked",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.with_mnemonic (_("_Undo"));
    g.add (new Label (msg));
    g.add (b);

    notification.show_all ();
    window.add_notification (notification);

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
    window.select_button.set_active (false);

    var notification = new Gd.Notification ();
    notification.timeout = 5;

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg = ngettext ("%d contact deleted",
                           "%d contacts deleted",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.with_mnemonic (_("_Undo"));
    g.add (new Label (msg));
    g.add (b);

    notification.show_all ();
    window.add_notification (notification);

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
    window.right_title = "";
    window.done_button.hide ();
    contacts_pane.set_edit_mode (false);

    var notification = new Gd.Notification ();
    notification.timeout = 5;

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    var label = new Label (_("Contact deleted: \"%s\"").printf (contact.display_name));
    label.set_max_width_chars (45);
    label.set_ellipsize (Pango.EllipsizeMode.END);
    var b = new Button.with_mnemonic (_("_Undo"));
    g.add (label);
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
    window.add_notification (notification);
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
    notification.timeout = 5;

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg;
    if (main_contact != null)
      msg = _("%s linked to %s").printf (main_contact, linked_contact);
    else
      msg = _("%s linked to the contact").printf (linked_contact);

    var b = new Button.with_mnemonic (_("_Undo"));
    g.add (new Label (msg));
    g.add (b);

    notification.show_all ();
    b.clicked.connect ( () => {
      notification.dismiss ();
      operation.undo.begin ();
    });
    window.add_notification (notification);
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
