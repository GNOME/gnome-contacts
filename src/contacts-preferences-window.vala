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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-preferences-window.ui")]
public class Contacts.PreferencesWindow : Adw.PreferencesWindow {

  [GtkChild]
  private unowned Adw.PreferencesPage address_books_page;

  public PreferencesWindow (Store contacts_store, Gtk.Window? transient_for) {
    Object (transient_for: transient_for, search_enabled: false);

    var acc_list = new AccountsList (contacts_store);
    acc_list.title = _("Address Books");
    acc_list.description = _("New contacts will be stored in the selected primary address book");
    this.address_books_page.add (acc_list);

    acc_list.notify["selected-store"].connect ((obj, pspec) => {
      var edsf_store = (Edsf.PersonaStore) acc_list.selected_store;
      contacts_store.set_primary_address_book (edsf_store);
    });

    var add_accounts_group = new Adw.PreferencesGroup ();
    add_accounts_group.title = _("Add address book");

    var goa_row = new Adw.ActionRow ();
    goa_row.title = _("GNOME Online Accounts");
    var goa_button = new Gtk.Button.from_icon_name ("external-link-symbolic");
    goa_button.tooltip_text = _("Opens the Online Accounts panel in GNOME Settings");
    goa_button.add_css_class ("flat");
    goa_button.clicked.connect (on_goa_button_clicked);
    goa_row.add_suffix (goa_button);
    goa_row.activatable_widget = goa_button;
    add_accounts_group.add (goa_row);

    var carddav_row = new Adw.ActionRow ();
    carddav_row.title = _("CardDAV account");
    var carddav_button = new Gtk.Button.from_icon_name ("go-next-symbolic");
    carddav_button.clicked.connect (on_carddav_button_clicked);
    carddav_button.add_css_class ("flat");
    carddav_row.add_suffix (carddav_button);
    carddav_row.activatable_widget = carddav_button;
    add_accounts_group.add (carddav_row);

    this.address_books_page.add (add_accounts_group);
  }

  private void on_carddav_button_clicked (Gtk.Button add_account_button) {
    var dialog = new AddAddressBookDialog (this);
    dialog.present ();
  }

  private void on_goa_button_clicked (Gtk.Button goa_button) {
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
}
