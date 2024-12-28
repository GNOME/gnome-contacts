/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
    { "show-contact", on_show_contact, "s" },
    { "import", on_import },
    { "export-all", on_export_all }
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

  public async void show_individual_for_id (string id)
      requires (this.window != null) {

    uint pos = yield this.contacts_store.find_individual_for_id (id);
    if (pos != Gtk.INVALID_LIST_POSITION) {
      bool can_navigate = yield this.window.navigation_request ();
      if (can_navigate)
        this.window.selection_model.select_item (pos, true);
    } else {
      var dialog = new Adw.AlertDialog (_("Contact not found"),
                                        _("No contact with id %s found").printf (id));
      dialog.add_response ("close", _("_Close"));
      dialog.default_response = "close";
      dialog.present (this.window);
    }
  }

  public void show_preferences () {
    var prefs_window = new PreferencesWindow (this.contacts_store);
    prefs_window.present (this.window);
  }

  public void show_help () {
    Gtk.UriLauncher help_launcher = new Gtk.UriLauncher ("help:gnome-help/contacts");
    help_launcher.launch.begin (this.window, null, (obj, res) => {
      try {
        help_launcher.launch.end (res);
      } catch (Error error) {
        warning ("Could not open help: %s", error.message);
      }
    });
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

    var about = new Adw.AboutDialog () {
        application_name = Environment.get_application_name (),
        application_icon = Config.APP_ID,
        developer_name = _("The GNOME Project"),
        version = Config.PACKAGE_VERSION,
        website = "https://apps.gnome.org/Contacts",
        issue_url = "https://gitlab.gnome.org/GNOME/gnome-contacts/-/issues/",
        developers = developers,
        designers = designers,
        translator_credits = _("translator-credits"),
        copyright = _("© 2011 Red Hat, Inc.\n© 2011-2020 The Contacts Developers"),
        license_type = Gtk.License.GPL_2_0
      };

      about.present (this.window);
  }

  public async void show_by_email (string email_address)
      requires (this.window != null) {
    var query = new SimpleQuery (email_address, { "email-addresses" });
    uint pos = yield this.contacts_store.find_individual_for_query (query);
    if (pos != Gtk.INVALID_LIST_POSITION) {
      bool can_navigate = yield this.window.navigation_request ();
      if (can_navigate)
        this.window.selection_model.select_item (pos, true);
    } else {
      var dialog = new Adw.AlertDialog (_("Contact not found"),
                                        _("No contact with email address %s found").printf (email_address));
      dialog.add_response ("close", _("_Close"));
      dialog.default_response = "close";
      dialog.present (this.window);
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
    ulong quiescence_id = this.contacts_store.quiescent.connect (() => {
      Source.remove (timeout_id);
      debug ("Got quiescent in time. Showing contact list");
      this.window.show_contact_list ();
      check_primary_address_book ();
    });

    // Timeout callback
    timeout_id = Timeout.add_seconds (LOADING_TIMEOUT, () => {
      this.contacts_store.disconnect (quiescence_id);

      debug ("Didn't achieve quiescence in time! Showing contact list anyway");
      this.window.show_contact_list ();
      check_primary_address_book ();
      return Source.REMOVE;
    });
  }

  /* At the time of quiescence, check if the primary store is not null. If it
   * is, we should warn the user to maybe check their address books */
  private void check_primary_address_book () {
    if (this.contacts_store.aggregator.primary_store != null)
      return;

    var dialog = new Adw.AlertDialog (_("Primary address book not found"),
                                      null);
    dialog.body = _("Contacts can't find the configured primary address book. You might experience issues creating or editing contacts");
    dialog.add_response ("preferences", _("Go To _Preferences"));
    dialog.set_default_response ("preferences");
    dialog.set_response_appearance ("preferences", Adw.ResponseAppearance.SUGGESTED);
    dialog.add_response ("cancel", _("_Cancel"));
    dialog.set_close_response ("cancel");
    dialog.response.connect ((response) => {
      if (response == "preferences")
        show_preferences ();
      dialog.destroy ();
    });
    dialog.present (this.window);
  }

  public override void startup () {
    if (!ensure_eds_accounts (true))
      quit ();

    base.startup ();

    GLib.Environment.set_application_name (_("Contacts"));
    Gtk.Window.set_default_icon_name (Config.APP_ID);

    create_actions ();
  }

  private void create_actions () {
    this.add_action_entries (action_entries, this);

    this.set_accels_for_action ("app.help", {"F1"});
    this.set_accels_for_action ("app.show-preferences", {"<Control>comma"});
    this.set_accels_for_action ("app.quit", {"<Control>q"});
  }

  public override void activate () {
    var active_window = get_active_window();
    if (active_window != null) {
      active_window.present ();
      return;
    }

    // If not, the new window depends on whether the user still needs setup
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
      this.contacts_store.set_primary_address_book (edsf_store);
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

  private void on_import (SimpleAction action, Variant? param) {
    var file_dialog = new Gtk.FileDialog ();
    file_dialog.title = _("Select contact file");
    file_dialog.accept_label = _("Import");
    file_dialog.modal = true;

    // TODO: somehow get this from the list of importers we have
    var filters = new ListStore (typeof (Gtk.FileFilter));
    var filter = new Gtk.FileFilter ();
    filter.set_filter_name (_("vCard files"));
    filter.add_pattern ("*.vcf");
    filter.add_pattern ("*.vcard");
    filters.append (filter);
    file_dialog.filters = filters;


    file_dialog.open_multiple.begin (this.window, null, (obj, res) => {
      try {
        var files = file_dialog.open_multiple.end (res);
        if (files == null) {
          debug ("No files selected, or no path available");
          return;
        }

        var import_dialog = new ImportDialog (this.contacts_store, files);
        import_dialog.present (this.window);
      } catch (Error error) {
        switch (error.code) {
          case Gtk.DialogError.CANCELLED:
          case Gtk.DialogError.DISMISSED:
            debug ("Dismissed opening file: %s", error.message);
            break;
          case Gtk.DialogError.FAILED:
          default:
            warning ("Could not open file: %s", error.message);
            break;
        }
      }
    });
  }

  private void on_export_all (SimpleAction action, Variant? param) {
    var model = this.contacts_store.individuals;
    var individuals = new Gee.ArrayList<Individual> ();
    for (uint i = 0; i < model.get_n_items (); i++)
      individuals.add ((Individual) model.get_item (i));
    this.window.export_individuals (individuals);
  }
}
