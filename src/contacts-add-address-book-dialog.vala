/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-add-address-book-dialog.ui")]
public class Contacts.AddAddressBookDialog : Gtk.Dialog {

  // The "scratch source" that we will end up saving
  private E.Source e_source;

  public AddressBookType address_book_type { get; construct set; }

  [GtkChild]
  private unowned Adw.EntryRow address_book_name_row;

  [GtkChild]
  private unowned Adw.EntryRow server_row;
  [GtkChild]
  private unowned Adw.EntryRow username_row;
  [GtkChild]
  private unowned Adw.PasswordEntryRow password_row;
  [GtkChild]
  private unowned Gtk.Button connect_button;

  [GtkChild]
  private unowned Gtk.Stack bottom_stack;
  [GtkChild]
  private unowned Gtk.Label error_label;

  [GtkChild]
  private unowned Adw.PreferencesGroup address_books_group;
  private DiscoveredSourceRow? selected_source_row = null;

  [GtkChild]
  private unowned Gtk.Button add_button;
  //XXX only make sensitive once selected-source-row is set

  static construct {
    install_action ("address-book.connect", null, (Gtk.WidgetActionActivateFunc) connect_action);
    install_action ("address-book.save", null, (Gtk.WidgetActionActivateFunc) save_action);
  }

  construct {
    // Initial widget state
    this.use_header_bar = 1;

    // Create a so-called scratch source
    this.e_source = new E.Source (null, null);

    // Set the backend name depending on the address book type
    var ab_extension = (E.SourceAddressBook)
        this.e_source.get_extension (E.SOURCE_EXTENSION_ADDRESS_BOOK);
    ab_extension.set_backend_name (this.address_book_type.to_e_backend_name ());
  }

  public AddAddressBookDialog (Gtk.Window? parent_window) {
    // NOTE: we only support CardDAV for now
    Object (address_book_type: AddressBookType.CARDDAV,
            transient_for: parent_window);
  }

  private void connect_action (string action_name, Variant? parameter) {
    this.connect_button.sensitive = false;

    connect_to_server.begin (null, (obj, res) => {
      try {
        connect_to_server.end (res);
      } catch (Error e) {
        warning ("Couldn't connect: %s[%d] %s", e.domain.to_string(), e.code, e.message);

        // We can use ESoupSessionError to find out errors that match a
        // specific HTTP code
        if (e.domain == E.SoupSession.error_quark ()) {
          if (e.code == 401) {
            show_error (_("Error: Invalid username or password"));
          } else {
            show_error (_("Error: server returned HTTP %u").printf (e.code));
          }
        } else if (e.domain == UriError.quark ()) {
          show_error (_("Error: Invalid URL"));
        } else {
          show_error (_("Error connecting to the server"));
        }
      } finally {
        this.connect_button.sensitive = true;
      }
    });
  }

  private void save_action (string action_name, Variant? parameter) {
    save.begin (null, (obj, res) => {
      try {
        save.end (res);
      } catch (Error e) {
          //XXX show something in the UI
        warning ("Couldn't save: %s", e.message);
      }
    });
    close ();
  }

  [GtkCallback]
  private void on_address_book_name_row_notify_text (Object object, ParamSpec pspec) {
    check_connect_button ();
  }

  [GtkCallback]
  private void on_server_row_notify_text (Object object, ParamSpec pspec) {
    check_connect_button ();
  }

  [GtkCallback]
  private void on_username_row_notify_text (Object object, ParamSpec pspec) {
    check_connect_button ();
  }

  [GtkCallback]
  private void on_password_row_notify_text (Object object, ParamSpec pspec) {
    check_connect_button ();
  }

  private void check_connect_button () {
    // XXX check also if uri is valid
    // XXX maybe set warning label?
    this.connect_button.sensitive =
        (this.username_row.text.strip () != "" &&
         this.password_row.text != "" &&
         this.server_row.text.strip () != "");
  }

  private void show_error (string label) {
    this.error_label.label = label;
    this.bottom_stack.visible_child_name = "error";
  }

  private async void connect_to_server (Cancellable? cancellable) throws Error {
    // First of all try to parse the URI (if it fails, it throws an error)
    var uri = Uri.parse (this.server_row.text, UriFlags.NONE);

    // Do a basic check that we have a connection to E-D-S
    //XXX maybe we can just create a registry here?
    if (!ensure_eds_accounts (true)) {
      warning ("Can't connect to evolution-data-server");
      return;// XXX throw error
    }

    // The basic details
    var ab_name = this.address_book_name_row.text;
    debug ("Connecting to source '%s' (type: %s)", ab_name, this.address_book_type.to_string ());

    if (ab_name.strip () != "")
      this.e_source.display_name = ab_name;

    // Get the webdav and auth extensions to set those
    var webdav_ext = (E.SourceWebdav)
        this.e_source.get_extension (E.SOURCE_EXTENSION_WEBDAV_BACKEND);
    webdav_ext.uri = uri;

    var auth_ext = (E.SourceAuthentication)
        this.e_source.get_extension (E.SOURCE_EXTENSION_AUTHENTICATION);
    auth_ext.user = this.username_row.text;

    // Credentials
    var credentials = new E.NamedParameters ();
    credentials.set (E.SOURCE_CREDENTIAL_USERNAME, this.username_row.text);
    credentials.set (E.SOURCE_CREDENTIAL_PASSWORD, this.password_row.text);

    debug ("Discovering address books for '%s'", ab_name);
    this.bottom_stack.visible_child_name = "loading";

    // Discover which address books are available at the server
    string cert_pem;
    TlsCertificateFlags cert_errors;
    SList<E.WebDAVDiscoveredSource> discovered_sources;
    SList<string> discovered_email_addrs;
    yield this.e_source.webdav_discover_sources (null,
                                                 E.WebDAVDiscoverSupports.CONTACTS,
                                                 credentials,
                                                 cancellable,
                                                 out cert_pem,
                                                 out cert_errors,
                                                 out discovered_sources,
                                                 out discovered_email_addrs);
    debug ("Discovered %u address books", discovered_sources.length ());

    if (discovered_sources.length () == 0) {
      show_error (_("No address books found"));
      return;
    }

    // Give the user the option to select which one to import
    this.bottom_stack.visible_child_name = "address_books";
    this.address_books_group.description = ngettext (
        "Found %u address book to import",
        "Found %u address books. Please select the address book you want to import",
        discovered_sources.length ()).printf (discovered_sources.length ());
    foreach (unowned var s in discovered_sources) {
      debug ("SOURCE '%s' (%s): '%s'", s.display_name, s.href, s.description);

      var source_row = new DiscoveredSourceRow (s);
      this.address_books_group.add (source_row);
      source_row.activated.connect ((row) => {
        unowned var src_row = (DiscoveredSourceRow) row;
        if (src_row == this.selected_source_row)
          return;

        this.selected_source_row.selected = false;
        src_row.selected = true;
        this.selected_source_row = src_row;
      });
    }
  }

  public async void save (Cancellable? cancellable) throws Error
      requires (this.selected_source_row != null) {
    // Note that eds_source_registry is guaranteed to be non-null due to
    // ensure_eds_accounts()
      //XXX maybe do create our own registry?
    if (eds_source_registry == null)
      error ("eds_source_registry is null");

    var selected_source = this.selected_source_row.source;
    if (selected_source.href != null && selected_source.href != "") {
      var webdav_ext = (E.SourceWebdav)
          this.e_source.get_extension (E.SOURCE_EXTENSION_WEBDAV_BACKEND);
      var uri = Uri.parse (this.server_row.text, UriFlags.NONE);
      webdav_ext.uri = uri;
    }

    debug ("Saving source '%s'", this.e_source.display_name);
    yield eds_source_registry.commit_source (this.e_source, cancellable);
    debug ("Saved source '%s'", this.e_source.display_name);
  }

  // Helper class to show a remote address book that can be imported
  private class DiscoveredSourceRow : Adw.ActionRow {

    public E.WebDAVDiscoveredSource source { get; construct set; }

    public bool selected { get; set; default = false; }

    public DiscoveredSourceRow (E.WebDAVDiscoveredSource source) {
      Object (source: source);

      this.title = source.display_name;
      if (source.description != null && source.description != "")
        this.subtitle = source.description;

      var checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic");
      bind_property ("selected", checkmark, "visible", BindingFlags.SYNC_CREATE);
      add_suffix (checkmark);
      this.activatable_widget = checkmark;
    }
  }
}
