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
  public Window window;
  public static App app;
  private Store contacts_store;
  private ListPane list_pane;
  private ContactPane contacts_pane;

  private bool window_delete_event (Gdk.EventAny event) {
    // Clear the contacts so any changed information is stored
    contacts_pane.show_contact (null);
    return false;
  }

  private bool window_map_event (Gdk.EventAny event) {
    list_pane.filter_entry.grab_focus ();
    return true;
  }

  private void selection_changed (Contact? new_selection) {
    contacts_pane.show_contact (new_selection);
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
				      _("No contact with id %s found").printf (id));
      dialog.set_title(_("Contact not found"));
      dialog.show ();
      dialog.response.connect ( (id) => {
	  dialog.destroy ();
	});
    }
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
				      _("No contact with email address %s found").printf (email_address));
      dialog.set_title(_("Contact not found"));
      dialog.show ();
      dialog.response.connect ( (id) => {
	  dialog.destroy ();
	});
    }
  }

  private void create_window () {
    try {
      var provider = new CssProvider ();
      provider.load_from_path (Config.PKGDATADIR + "/" + "gnome-contacts.css");
      StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider,
					    STYLE_PROVIDER_PRIORITY_APPLICATION);
    } catch {
      warning ("Failed to load custom CSS");
    }

    this.app = this;
    window = new Window ();
    window.set_application (this);
    window.set_title (_("Contacts"));
    window.set_size_request (745, 510);
    window.delete_event.connect (window_delete_event);
    window.map_event.connect (window_map_event);

    var grid = new Grid();
    window.add (grid);

    list_pane = new ListPane (contacts_store);
    list_pane.selection_changed.connect (selection_changed);
    list_pane.create_new.connect ( () => {
	contacts_pane.new_contact (list_pane);
      });

    grid.attach (list_pane, 0, 0, 1, 2);

    contacts_pane = new ContactPane (contacts_store);
    contacts_pane.set_hexpand (true);
    grid.attach (contacts_pane, 1, 0, 1, 2);

    grid.show_all ();
  }

  public override void startup () {
    ensure_eds_accounts ();
    contacts_store = new Store ();
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
