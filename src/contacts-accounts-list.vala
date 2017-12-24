/*
 * Copyright (C) 2011 Erick Pérez Castellanos <erick.red@gmail.com>
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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-accounts-list.ui")]
public class Contacts.AccountsList : Box {
  [GtkChild]
  private ListBox accounts_view;

  private ListBoxRow last_selected_row;

  private Store contacts_store;

  public PersonaStore? selected_store;

  public signal void account_selected ();

  public AccountsList (Store contacts_store) {
    this.contacts_store = contacts_store;
    this.selected_store = null;

    this.accounts_view.set_header_func (add_separator);
    this.accounts_view.row_activated.connect (row_activated);
  }

  private void row_activated (ListBoxRow? row) {
    if (row == null)
      return;

    if (last_selected_row != null &&
        last_selected_row == row) {
      return;
    }

    var row_data = (row as Bin).get_child () as Grid;
    var checkmark = new Image.from_icon_name ("object-select-symbolic", IconSize.MENU);
    checkmark.set ("margin-end", 12,
                   "valign", Align.CENTER,
                   "halign", Align.END,
                   "vexpand", true,
                   "hexpand", true);
    checkmark.show ();
    row_data.attach (checkmark, 2, 0, 1, 2);

    if (last_selected_row != null) {
      var last_row_data = (last_selected_row as Bin).get_child () as Grid;
      if (last_row_data != null)
        last_row_data.get_child_at (2, 0).destroy ();
    }

    last_selected_row = row;

    selected_store = row_data.get_data<PersonaStore> ("store");

    account_selected ();
  }

  public void update_contents (bool select_active) {
    foreach (var child in accounts_view.get_children ()) {
      child.destroy ();
    }

    PersonaStore local_store = null;
    foreach (var persona_store in Utils.get_eds_address_books (this.contacts_store)) {
      if (persona_store.id == "system-address-book") {
        local_store = persona_store;
        continue;
      }
      var source = (persona_store as Edsf.PersonaStore).source;
      var parent_source = eds_source_registry.ref_source (source.parent);

      var provider_name = Contact.format_persona_store_name (persona_store);

      var source_account_id = "";
      if (parent_source.has_extension (E.SOURCE_EXTENSION_GOA)) {
        var goa_source_ext = parent_source.get_extension (E.SOURCE_EXTENSION_GOA) as E.SourceGoa;
        source_account_id = goa_source_ext.account_id;
      }

      var row_data = new Grid ();
      row_data.set_data ("store", persona_store);
      row_data.margin = 6;
      row_data.margin_start = 5;
      row_data.set_row_spacing (1);
      row_data.set_column_spacing (10);

      if (source_account_id != "") {
        var provider_image = Contacts.get_icon_for_goa_account (source_account_id);
        row_data.attach (provider_image, 0, 0, 1, 2);
      } else {
        var provider_image = new Image.from_icon_name ("gnome-contacts",
                                                       IconSize.DIALOG);
        row_data.attach (provider_image, 0, 0, 1, 2);
      }

      var provider_label = new Label (provider_name);
      provider_label.set_halign (Align.START);
      provider_label.set_hexpand (true);
      provider_label.set_valign (Align.END);
      row_data.attach (provider_label, 1, 0, 1, 1);

      var account_name = parent_source.display_name;
      var account_label = new Label (account_name);
      account_label.set_halign (Align.START);
      account_label.set_hexpand (true);
      account_label.set_valign (Align.START);
      account_label.get_style_context ().add_class ("dim-label");
      row_data.attach (account_label, 1, 1, 1, 1);

      accounts_view.add (row_data);

      if (select_active &&
          persona_store == this.contacts_store.aggregator.primary_store) {
        var row = row_data.get_parent () as ListBoxRow;
        row_activated (row);
      }
    }

    if (local_store != null) {
      var local_data = new Grid ();
      local_data.margin = 6;
      local_data.margin_start = 5;
      local_data.set_column_spacing (10);
      local_data.set_data ("store", local_store);
      var provider_image = new Image.from_icon_name ("gnome-contacts",
                                                     IconSize.DIALOG);
      local_data.add (provider_image);
      var local_label = new Label (_("Local Address Book"));
      local_data.add (local_label);
      accounts_view.add (local_data);
      if (select_active &&
          local_store == this.contacts_store.aggregator.primary_store) {
        var row = local_data.get_parent () as ListBoxRow;
        row_activated (row);
      }
    }

    accounts_view.show_all ();
  }

  [GtkCallback]
  private void on_goa_button_clicked () {
    try {
      var proxy = new DBusProxy.for_bus_sync (BusType.SESSION,
                                              DBusProxyFlags.NONE,
                                              null,
                                              "org.gnome.ControlCenter",
                                              "/org/gnome/ControlCenter",
                                              "org.gtk.Actions");

      var builder = new VariantBuilder (new VariantType ("av") );
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
