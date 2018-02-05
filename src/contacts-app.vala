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
  private Settings settings;

  private Store contacts_store;

  private Window window;

  private bool is_prepare_scheluded = false;
  private bool is_quiescent_scheduled = false;

  private const GLib.ActionEntry[] action_entries = {
    { "quit",        quit                },
    { "help",        show_help           },
    { "about",       show_about          },
    { "change-book", change_address_book },
    { "new-contact", new_contact         }
  };

  private const OptionEntry[] options = {
    { "individual",  'i', 0, OptionArg.STRING, null, N_("Show contact with this individual id") },
    { "email",       'e', 0, OptionArg.STRING, null, N_("Show contact with this email address") },
    { "search",      's', 0, OptionArg.STRING                                                   },
    { "version",     'v', 0, OptionArg.NONE,   null, N_("Show the current version of Contacts") },
    {}
  };

  public App () {
    Object (
      application_id: "org.gnome.Contacts",
      flags: ApplicationFlags.HANDLES_COMMAND_LINE
    );

    this.settings = new Settings (this);
    add_main_option_entries (options);
	create_actions ();
  }

  public override int command_line (ApplicationCommandLine command_line) {
    var options = command_line.get_options_dict ();

    activate ();

    if ("individual" in options) {
      var individual = options.lookup_value ("individual", VariantType.STRING);
      if (individual != null)
        show_individual.begin (individual.get_string ());
    } else if ("email" in options) {
      var email = options.lookup_value ("email", VariantType.STRING);
      if (email != null)
        show_by_email.begin (email.get_string ());
    } else if ("search" in options) {
      var search_term = options.lookup_value ("search", VariantType.STRING);
      if (search_term != null)
        show_search (search_term.get_string ());
    }

    return 0;
  }

  public override int handle_local_options (VariantDict options) {
    if ("version" in options) {
      stdout.printf ("gnome-contacts %s\n", Config.PACKAGE_VERSION);
      return 0;
    }

    return -1;
  }

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
      var dialog = new MessageDialog (this.window, DialogFlags.DESTROY_WITH_PARENT, MessageType.ERROR, ButtonsType.CLOSE,
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

    var acc = new AccountsList (this.contacts_store);
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
	    var settings = new GLib.Settings ("org.freedesktop.folks");
	    settings.set_string ("primary-store",
				 "eds:%s".printf(e_store.id));
	    contacts_store.refresh ();
	  }
	}
	contacts_store.disconnect (stores_changed_id);
	dialog.destroy ();
      });
  }

  public void show_help () {
    try {
      Gtk.show_uri_on_window (window, "help:gnome-help/contacts", Gtk.get_current_event_time ());
    } catch (GLib.Error e1) {
      warning ("Error showing help: %s", e1.message);
    }
  }

  public void show_about () {
    string[] authors = {
      "Alexander Larsson <alexl@redhat.com>",
      "Erick Pérez Castellanos <erick.red@gmail.com>",
      "Niels De Graef <nielsdegraef@gmail.com>"
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
                           "logo-icon-name", "gnome-contacts",
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
      var dialog = new MessageDialog (this.window, DialogFlags.DESTROY_WITH_PARENT, MessageType.ERROR, ButtonsType.CLOSE,
                                      _("No contact with email address %s found"), email_address);
      dialog.set_title(_("Contact not found"));
      dialog.show ();
      dialog.response.connect ( (id) => {
          dialog.destroy ();
        });
    }
  }

  public void show_search (string query) {
    if (contacts_store.is_quiescent) {
      window.show_search (query);
    } else {
      contacts_store.quiescent.connect_after (() => {
	  window.show_search (query);
	});
    }
  }

  private void create_actions () {
    this.add_action_entries (action_entries, this);

    this.set_accels_for_action ("app.help", {"F1"});
    this.set_accels_for_action ("app.new-contact", {"<Primary>n"});
  }

  private void create_window () {
    this.window = new Contacts.Window (this.settings, this, this.contacts_store);
  }

  private void schedule_window_creation () {
    /* window creation code is run after Store::prepare */
    hold ();
    ulong id = 0;
    uint id2 = 0;
    id = contacts_store.prepared.connect (() => {
	contacts_store.disconnect (id);
	Source.remove (id2);

	create_window ();
	window.show ();

	schedule_window_finish_ui ();

	release ();
      });
    // Wait at most 0.5 seconds to show the window
    id2 = Timeout.add (500, () => {
	contacts_store.disconnect (id);

	create_window ();
	window.show ();

	schedule_window_finish_ui ();

	release ();
	return false;
      });

    is_prepare_scheluded = true;
  }

  private void schedule_window_finish_ui () {
    /* make window swap spinner out and init Contacts.ListView */
    // We delay the initial show a tiny bit so most contacts are loaded when we show
    ulong id = 0;
    uint id2 = 0;
    id = contacts_store.quiescent.connect (() => {
	Source.remove (id2);
	contacts_store.disconnect (id);

	debug ("callign set_list_pane from quiescent.connect");
	window.set_list_pane ();
      });
    // Wait at most 0.5 seconds to show the window
    id2 = Timeout.add (500, () => {
	contacts_store.disconnect (id);

	debug ("callign set_list_pane from 500.timeout");
	window.set_list_pane ();
	return false;
      });

    is_quiescent_scheduled = true;
  }

  public override void startup () {
    if (!ensure_eds_accounts (true))
      quit ();

    this.contacts_store = new Store ();
    base.startup ();

    load_styling ();
  }

  public void load_styling () {
    var provider = new Gtk.CssProvider ();
    provider.load_from_resource ("/org/gnome/Contacts/ui/style.css");
    StyleContext.add_provider_for_screen (Gdk.Screen.get_default(),
                                          provider,
                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  public override void activate () {
    // Check if we've already done the setup process
    if (this.settings.did_initial_setup)
      create_new_window ();
    else
      run_setup ();
  }

  private void run_setup () {
    // Disable the change-book action (don't want the user to do that during setup)
    var change_book_action = lookup_action ("change-book") as SimpleAction;
    change_book_action.set_enabled (false);

    // Create and show the setup window
    var setup_window = new SetupWindow (this, this.contacts_store);
    setup_window.setup_done.connect ( (selected_store) => {
        setup_window.destroy ();

        eds_source_registry.set_default_address_book (selected_store.source);
        this.settings.did_initial_setup = true;

        change_book_action.set_enabled (true); // re-enable change-book action
        create_new_window ();
      });
    setup_window.show ();
  }

  private void create_new_window () {
    /* window creation code */
    if (window == null) {
      if (!this.contacts_store.is_prepared) {
	if (!is_prepare_scheluded) {
	  schedule_window_creation ();
	  return;
	}
      }

      create_window ();
      window.show ();
    }

    if (this.contacts_store.is_quiescent) {
      debug ("callign set_list_pane cause store is already quiescent");
      window.set_list_pane ();
    } else if (!is_quiescent_scheduled) {
      schedule_window_finish_ui ();
    }

    if (window != null)
      window.present ();
  }

  public void new_contact () {
    window.new_contact ();
  }
}
