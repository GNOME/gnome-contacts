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
using Hdy;
using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-accounts-list.ui")]
public class Contacts.AccountsList : ListBox {
  private ListBoxRow last_selected_row;

  private Store contacts_store;

  public PersonaStore? selected_store;

  public signal void account_selected ();

  public AccountsList (Store contacts_store) {
    this.contacts_store = contacts_store;
    this.selected_store = null;

    this.set_header_func (add_separator);
  }

  public override void row_activated (ListBoxRow row) {
    if (row == null)
      return;

    if (last_selected_row != null &&
        last_selected_row == row) {
      return;
    }

    var checkmark = row.get_data<Image> ("checkmark");
    checkmark.show ();

    if (last_selected_row != null) {
      checkmark = last_selected_row.get_data<Image> ("checkmark");
      if (checkmark != null)
        checkmark.hide ();
    }

    last_selected_row = row;

    selected_store = row.get_data<PersonaStore> ("store");

    account_selected ();
  }

  public void update_contents (bool select_active) {
    foreach (var child in get_children ()) {
      child.destroy ();
    }

    // Fill the list with address book
    PersonaStore[] eds_stores = Utils.get_eds_address_books (this.contacts_store);
    debug ("Found %d EDS stores", eds_stores.length);

    PersonaStore? local_store = null;
    foreach (var persona_store in eds_stores) {
      if (persona_store.id == "system-address-book") {
        local_store = persona_store;
        continue;
      }
      var source = (persona_store as Edsf.PersonaStore).source;
      var parent_source = eds_source_registry.ref_source (source.parent);
      var provider_name = Contacts.Utils.format_persona_store_name (persona_store);

      debug ("Contact store \"%s\"", provider_name);

      var source_account_id = "";
      if (parent_source.has_extension (E.SOURCE_EXTENSION_GOA)) {
        var goa_source_ext = parent_source.get_extension (E.SOURCE_EXTENSION_GOA) as E.SourceGoa;
        source_account_id = goa_source_ext.account_id;
      }

      var row = new ActionRow ();
      row.set_data ("store", persona_store);

      Gtk.Image provider_image;
      if (source_account_id != "")
        provider_image = Contacts.get_icon_for_goa_account (source_account_id);
      else
        provider_image = new Image.from_icon_name (Config.APP_ID, IconSize.DIALOG);
      row.add_prefix (provider_image);
      row.title = provider_name;
      row.subtitle = parent_source.display_name;
      row.show_all ();
      row.no_show_all = true;
      var checkmark = new Image.from_icon_name ("object-select-symbolic", IconSize.MENU);
      checkmark.set ("margin-end", 6,
                     "valign", Align.CENTER,
                     "halign", Align.END,
                     "vexpand", true,
                     "hexpand", true);
      row.add_action (checkmark);
      row.set_data ("checkmark", checkmark);
      add (row);

      if (select_active &&
          persona_store == this.contacts_store.aggregator.primary_store) {
        row_activated (row);
      }
    }

    if (local_store != null) {
      var local_row = new ActionRow ();
      var provider_image = new Image.from_icon_name (Config.APP_ID, IconSize.DIALOG);
      local_row.add_prefix (provider_image);
      local_row.title = _("Local Address Book");
      local_row.show_all ();
      local_row.no_show_all = true;
      var checkmark = new Image.from_icon_name ("object-select-symbolic", IconSize.MENU);
      checkmark.set ("margin-end", 6,
                     "valign", Align.CENTER,
                     "halign", Align.END,
                     "vexpand", true,
                     "hexpand", true);
      local_row.add_action (checkmark);
      local_row.set_data ("checkmark", checkmark);
      add (local_row);
      if (select_active &&
          local_store == this.contacts_store.aggregator.primary_store) {
        row_activated (local_row);
      }
    }

    show_all ();
  }
}
