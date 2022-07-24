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

  // The operations that have been (or are being) executed
  public Contacts.OperationList operations {
    get;
    private set;
    default = new OperationList ();
  }

  private const GLib.ActionEntry[] action_entries = {
    { "quit",             quit_action         },
    { "help",             show_help           },
    { "about",            show_about          },
    { "show-preferences", show_preferences },
    { "show-contact",     on_show_contact, "s"}
  };

  private const OptionEntry[] options = {
    { "email",       'e', 0, OptionArg.STRING, null, N_("Show contact with this email address") },
    { "individual",  'i', 0, OptionArg.STRING, null, N_("Show contact with this individual id") },
    { "search",      's', 0, OptionArg.STRING, null, N_("Show contacts with the given filter") },
    { "version",     'v', 0, OptionArg.NONE,   null, N_("Show the current version of Contacts") },
    {}
  };

  construct {
    this.settings = new Settings (this);

    string[] filtered_fields = Query.MATCH_FIELDS_NAMES;
    foreach (unowned var field in Query.MATCH_FIELDS_ADDRESSES)
      filtered_fields += field;
    var query = new SimpleQuery ("", filtered_fields);

    this.contacts_store = new Store (this.settings, query);

    add_main_option_entries (options);
  }

  public App () {
    Object (
      application_id: Config.APP_ID,
      resource_base_path: "/org/gnome/Contacts",
      flags: ApplicationFlags.HANDLES_COMMAND_LINE
    );
  }

  public override int command_line (ApplicationCommandLine command_line) {
    var options = command_line.get_options_dict ();

    activate ();

    if ("individual" in options) {
      var individual = options.lookup_value ("individual", VariantType.STRING);
      if (individual != null)
        show_individual_for_id.begin (individual.get_string ());
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

  public async void show_individual_for_id (string id) {
    uint pos = yield this.contacts_store.find_individual_for_id (id);
    if (pos != Gtk.INVALID_LIST_POSITION) {
      this.contacts_store.selection.selected = pos;
    } else {
      var dialog = new Adw.MessageDialog (this.window,
                                          _("Contact not found"),
                                          _("No contact with id %s found").printf (id));
      dialog.add_response ("close", _("_Close"));
      dialog.default_response = "close";
      dialog.show ();
    }
  }

  public void change_address_book () {
    var dialog = new AddressbookDialog (this.contacts_store, this.window);
    dialog.response.connect ((_) => dialog.close ());
    dialog.show ();
  }

  public void show_preferences () {
    var prefs_window = new PreferencesWindow (this.contacts_store, this.window);
    prefs_window.show ();
  }

  public void show_help () {
    // FIXME: use show_uri_full(), so we can report errors
    Gtk.show_uri (this.window, "help:gnome-help/contacts", Gdk.CURRENT_TIME);
  }

  public void show_about () {
    string[] developers = {
      "Alexander Larsson <alexl@redhat.com>",
      "Erick Pérez Castellanos <erick.red@gmail.com>",
      "Niels De Graef <nielsdegraef@gmail.com>",
      "Julian Sparber <jsparber@gnome.org>"
    };
    string[] designers = {
      "Allan Day <allanpday@gmail.com>"
    };

    var about = new Adw.AboutWindow () {
        transient_for = this.window,
        application_name = Environment.get_application_name (),
        application_icon = Config.APP_ID,
        developer_name = _("The GNOME Project"),
        version = Config.PACKAGE_VERSION,
        website = "https://wiki.gnome.org/Apps/Contacts",
        issue_url = "https://gitlab.gnome.org/GNOME/gnome-contacts/-/issues/new",
        developers = developers,
        designers = designers,
        copyright = _("© 2011 Red Hat, Inc.\n© 2011-2020 The Contacts Developers"),
        license_type = Gtk.License.GPL_2_0
      };

      about.present ();
  }

  public async void show_by_email (string email_address) {
    var query = new SimpleQuery (email_address, { "email-addresses" });
    uint pos = yield this.contacts_store.find_individual_for_query (query);
    if (pos != Gtk.INVALID_LIST_POSITION) {
      this.contacts_store.selection.selected = pos;
    } else {
      var dialog = new Adw.MessageDialog (this.window,
                                          _("Contact not found"),
                                          _("No contact with email address %s found").printf (email_address));
      dialog.add_response ("close", _("_Close"));
      dialog.default_response = "close";
      dialog.show ();
    }
  }

  public void show_search (string query) {
    if (this.contacts_store.aggregator.is_quiescent) {
      this.window.show_search (query);
    } else {
      this.contacts_store.quiescent.connect_after (() => {
        this.window.show_search (query);
      });
    }
  }

  private void create_window () {
    var win = new MainWindow (this.settings, this.operations, this, this.contacts_store);
    win.close_request.connect_after ((win) => {
      activate_action ("quit", null);
      return false;
    });
    this.window = win;
    win.present ();

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

    // Create and show the setup window
    var setup_window = new SetupWindow (this, this.contacts_store);
    setup_window.setup_done.connect ((selected_store) => {
      setup_window.destroy ();

      unowned var edsf_store = (Edsf.PersonaStore) selected_store;
      Utils.set_primary_store (edsf_store);
      this.settings.did_initial_setup = true;

      create_window ();
    });
    setup_window.show ();
  }

  private void on_show_contact (SimpleAction action, Variant? param) {
    activate ();

    var individual_id = param as string;
    if (individual_id != null)
      show_individual_for_id.begin (individual_id);
  }

  private void quit_action (SimpleAction action, Variant? param) {
    if (!this.operations.has_pending_operations ()) {
      debug ("No more operations pending. Quitting immediately");
      base.quit ();
    }

    debug ("Some operations still pending, delaying shutdown");

    // We still have operations pending but the user requested to quit, so
    // give it still a limited amount of time to still get them done
    if (this.window != null)
      this.window.hide ();

    Timeout.add_seconds (5, () => {
      warning ("Some operations have not finished yet!");
      base.quit ();
      return Source.REMOVE;
    });

    this.operations.flush.begin ((obj, res) => {
      try {
        this.operations.flush.end (res);
        debug ("Succesfully flushed operations before quitting");
      } catch (Error e) {
        warning ("Error flushing operations: %s", e.message);
      }
      base.quit ();
    });
  }
}
