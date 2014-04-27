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
  public static App app;
  public GLib.Settings settings;

  /* moving creation to Window */
  public weak Store contacts_store;

  public Contacts.Window window;

  private bool app_menu_created;

  public void show_contact (Contact? contact) {
    window.set_shown_contact (contact);
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
    var dialog = new Dialog.with_buttons (_("Change Address Book"),
					  (Window) window,
					  DialogFlags.MODAL |
					  DialogFlags.DESTROY_WITH_PARENT |
					  DialogFlags.USE_HEADER_BAR,
					  _("Change"), ResponseType.OK,
					  _("Cancel"), ResponseType.CANCEL,
					  null);

    var ok_button = dialog.get_widget_for_response (ResponseType.OK);
    ok_button.sensitive = false;
    ok_button.get_style_context ().add_class ("suggested-action");
    dialog.set_resizable (false);
    dialog.set_border_width (12);

    var explanation_label = new Label (_("New contacts will be added to the selected address book.\nYou are able to view and edit contacts from other address books."));
    (dialog.get_content_area () as Box).add (explanation_label);
    (dialog.get_content_area () as Box).set_spacing (12);

    var acc = new AccountsList ();
    acc.update_contents (true);

    ulong active_button_once = 0;
    active_button_once = acc.account_selected.connect (() => {
	ok_button.sensitive = true;
	acc.disconnect (active_button_once);
      });

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
                           "copyright", "Copyright 2011 Red Hat, Inc.\nCopyright 2014 The Contacts Developers",
                           "license-type", Gtk.License.GPL_2_0,
                           "logo-icon-name", "x-office-address-book",
                           "version", Config.PACKAGE_VERSION,
                           "website", "https://wiki.gnome.org/Apps/Contacts",
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

  private void create_app_menu () {
    var action = new GLib.SimpleAction ("quit", null);
    action.activate.connect (() => { this.quit (); });
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
  }

  private void create_window () {
    window = new Contacts.Window (this);

    /* FIXME: place where it should be placed */
    //contacts_store = window.contacts_store;

    window.add_button.clicked.connect (app.new_contact);
  }

  public override void startup () {
    ensure_eds_accounts ();
    base.startup ();
  }

  private void show_setup () {
    var change_book_action = this.lookup_action ("change_book") as GLib.SimpleAction;
    change_book_action.set_enabled (false);

    var setup = new SetupWindow ();
    setup.set_application (this);
    setup.destroy.connect ( () => {
        setup.destroy ();
        if (setup.succeeded) {
          change_book_action.set_enabled (true);
          this.activate ();
        }
      });
    setup.show ();
  }

  public override void activate () {
    if (window == null) {
      if (!app_menu_created) {
        create_app_menu ();
        app_menu_created = true;
      }

      /* FIXME: setup code won't work for now */
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
    app_menu_created = false;
  }
}
