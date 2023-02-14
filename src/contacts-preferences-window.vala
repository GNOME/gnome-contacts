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
    acc_list.title = _("Primary Address Book");
    acc_list.description = _("New contacts will be added to the selected address book. You are able to view and edit contacts from other address books.");
    this.address_books_page.add (acc_list);

    acc_list.notify["selected-store"].connect ((obj, pspec) => {
      var edsf_store = (Edsf.PersonaStore) acc_list.selected_store;
      contacts_store.set_primary_address_book (edsf_store);
    });

    var goa_button_content = new Adw.ButtonContent ();
    goa_button_content.label = _("_Online Accounts");
    goa_button_content.use_underline = true;
    goa_button_content.icon_name = "external-link-symbolic";
    var goa_button = new Gtk.Button ();
    goa_button.set_child (goa_button_content);
    goa_button.tooltip_text = _("Open the Online Accounts panel in Settings");
    goa_button.margin_top = 36;
    goa_button.halign = Gtk.Align.CENTER;
    goa_button.add_css_class ("pill");
    goa_button.clicked.connect (on_goa_button_clicked);
    acc_list.add (goa_button);
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
