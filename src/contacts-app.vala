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

public class Contacts.App : Adw.Application {
  private Settings settings;

  private Store contacts_store;

  private unowned MainWindow window;

  private const GLib.ActionEntry[] action_entries = {
    { "quit",             quit                },
    { "help",             show_help           },
    { "about",            show_about          },
    { "change-book",      change_address_book },
    { "online-accounts",  online_accounts     },
    { "show-contact",     on_show_contact, "s"}
  };

  private const OptionEntry[] options = {
    { "email",       'e', 0, OptionArg.STRING, null, N_("Show contact with this email address") },
    { "individual",  'i', 0, OptionArg.STRING, null, N_("Show contact with this individual id") },
    { "search",      's', 0, OptionArg.STRING, null, N_("Show contacts with the given filter") },
    { "version",     'v', 0, OptionArg.NONE,   null, N_("Show the current version of Contacts") },
    {}
  };

  public App () {
    Object (
      application_id: Config.APP_ID,
      resource_base_path: "/org/gnome/Contacts",
      flags: ApplicationFlags.HANDLES_COMMAND_LINE
    );

    this.settings = new Settings (this);
    add_main_option_entries (options);
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
      stdout.printf ("%s %s\n", Config.PACKAGE_NAME, Config.PACKAGE_VERSION);
      return 0;
    }

    return -1;
  }

  public void show_contact (Individual? individual) {
    this.window.set_shown_contact (individual);
  }

  public async void show_individual (string id) {
    if (contacts_store.is_quiescent) {
      show_individual_ready.begin (id);
    } else {
      contacts_store.quiescent.connect (() => {
        show_individual_ready.begin (id);
      });
    }
  }

  private async void show_individual_ready (string id) {
    Individual? contact = null;
    try {
      contact = yield contacts_store.aggregator.look_up_individual (id);
    } catch (Error e) {
      debug ("Couldn't look up individual");
    }
    if (contact != null) {
      show_contact (contact);
    } else {
      var dialog = new Gtk.MessageDialog (this.window, Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                          Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
                                          _("No contact with id %s found"), id);
      dialog.set_title (_("Contact not found"));
      dialog.response.connect ((_) => { dialog.close (); });
      dialog.show ();
    }
  }

  public void change_address_book () {
    var dialog = new AddressbookDialog (this.contacts_store, this.window);
    dialog.response.connect ((_) => dialog.close ());
    dialog.show ();
  }

  public void online_accounts () {
    try {
      var proxy = new DBusProxy.for_bus_sync (BusType.SESSION,
                                              DBusProxyFlags.NONE,
                                              null,
                                              "org.gnome.Settings",
                                              "/org/gnome/Settings",
                                              "org.gtk.Actions");

      var builder = new VariantBuilder (new VariantType ("av"));
      builder.add ("v", new Variant.string (""));
      var param = new Variant.tuple ({
        new Variant.string ("launch-panel"),
        new Variant.array (new VariantType ("v"), {
          new Variant ("v", new Variant ("(sav)", "online-accounts", builder))
        }),
        new Variant.array (new VariantType ("{sv}"), {})
      });

      proxy.call_sync ("Activate", param, DBusCallFlags.NONE, -1);
    } catch (Error e) {
      // TODO: Show error dialog
      warning ("Couldn't open online-accounts: %s", e.message);
    }
  }

  public void show_help () {
    // FIXME: use show_uri_full(), so we can report errors
    Gtk.show_uri (this.window, "help:gnome-help/contacts", Gdk.CURRENT_TIME);
  }

  public void show_about () {
    string[] authors = {
      "Alexander Larsson <alexl@redhat.com>",
      "Erick Pérez Castellanos <erick.red@gmail.com>",
      "Niels De Graef <nielsdegraef@gmail.com>",
      "Julian Sparber <jsparber@gnome.org>"
    };
    string[] artists = {
      "Allan Day <allanpday@gmail.com>"
    };
    Gtk.show_about_dialog (this.window,
                           "artists", artists,
                           "authors", authors,
                           "translator-credits", _("translator-credits"),
                           "title", _("About GNOME Contacts"),
                           "comments", _("Contact Management Application"),
                           "copyright", _("© 2011 Red Hat, Inc.\n© 2011-2020 The Contacts Developers"),
                           "license-type", Gtk.License.GPL_2_0,
                           "logo-icon-name", Config.APP_ID,
                           "version", Config.PACKAGE_VERSION,
                           "website", "https://wiki.gnome.org/Apps/Contacts",
                           "wrap-license", true);
  }

  public async void show_by_email (string email_address) {
    var query = new SimpleQuery (email_address, { "email-addresses" });
    Individual individual = yield contacts_store.find_contact (query);
    if (individual != null) {
      show_contact (individual);
    } else {
      var dialog = new Gtk.MessageDialog (this.window, Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                          Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
                                          _("No contact with email address %s found"), email_address);
      dialog.set_title (_("Contact not found"));
      dialog.response.connect ((_) => dialog.close ());
      dialog.show ();
    }
  }

  public void show_search (string query) {
    if (contacts_store.is_quiescent) {
      this.window.show_search (query);
    } else {
      contacts_store.quiescent.connect_after (() => {
        this.window.show_search (query);
      });
    }
  }

  private void create_window () {
    var win = new MainWindow (this.settings, this, this.contacts_store);
    win.show ();
    this.window = win;

    show_contact_list ();
  }

  // We have to wait until our Store is quiescent before showing contacts.
  // However, some backends can take quite a while to load (or even timeout),
  // so make sure we also show something within a reasonable time frame.
  private const int LOADING_TIMEOUT = 1; // in seconds

  private void show_contact_list () {
    uint timeout_id = 0;

    // Happy flow callback
    ulong quiescence_id = contacts_store.quiescent.connect (() => {
      Source.remove (timeout_id);
      debug ("Got quiescent in time. Showing contact list");
      window.show_contact_list ();
    });

    // Timeout callback
    timeout_id = Timeout.add_seconds (LOADING_TIMEOUT, () => {
      contacts_store.disconnect (quiescence_id);

      debug ("Didn't achieve quiescence in time! Showing contact list anyway");
      window.show_contact_list ();
      return false;
    });
  }

  public override void startup () {
    if (!ensure_eds_accounts (true))
      quit ();

    this.contacts_store = new Store ();
    base.startup ();

    load_styling ();
    create_actions ();
  }

  private void create_actions () {
    this.add_action_entries (action_entries, this);

    this.set_accels_for_action ("app.help", {"F1"});
    this.set_accels_for_action ("app.quit", {"<Control>q"});
  }

  public void load_styling () {
    var provider = new Gtk.CssProvider ();
    provider.load_from_resource ("/org/gnome/Contacts/ui/style.css");
    Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (),
                                               provider,
                                               Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  public override void activate () {
    // Check if we've already done the setup process
    if (this.settings.did_initial_setup)
      create_window ();
    else
      run_setup ();
  }

  private void run_setup () {
    debug ("Running initial setup");

    // Disable change-book action (don't want the user to do that during setup)
    unowned var change_book_action = lookup_action ("change-book") as SimpleAction;
    change_book_action.set_enabled (false);

    // Create and show the setup window
    var setup_window = new SetupWindow (this, this.contacts_store);
    setup_window.setup_done.connect ((selected_store) => {
      setup_window.destroy ();

      eds_source_registry.set_default_address_book (selected_store.source);
      this.settings.did_initial_setup = true;

      change_book_action.set_enabled (true);   // re-enable change-book action
      create_window ();
    });
    setup_window.show ();
  }

  private void on_show_contact(SimpleAction action, Variant? param) {
    activate();

    var individual = param as string;
    if (individual != null)
      show_individual.begin (individual);
  }

}
