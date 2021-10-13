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

using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-accounts-list.ui")]
public class Contacts.AccountsList : Adw.Bin {

  [GtkChild]
  private unowned Gtk.ListBox listbox;
  private unowned Gtk.ListBoxRow? last_selected_row = null;

  private Store contacts_store;
  public PersonaStore? selected_store = null;

  public signal void account_selected ();

  construct {
    this.listbox.row_activated.connect (on_row_activated);
  }

  public AccountsList (Store contacts_store) {
    this.contacts_store = contacts_store;
  }

  private void on_row_activated (Gtk.ListBox listbox, Gtk.ListBoxRow? row) {
    if (row == null)
      return;

    if (this.last_selected_row != null &&
        this.last_selected_row == row) {
      return;
    }

    var checkmark = row.get_data<Gtk.Image> ("checkmark");
    checkmark.show ();

    if (last_selected_row != null) {
      checkmark = this.last_selected_row.get_data<Gtk.Image> ("checkmark");
      if (checkmark != null)
        checkmark.hide ();
    }

    // Update the fields
    this.last_selected_row = row;
    this.selected_store = row.get_data<PersonaStore> ("store");

    account_selected ();
  }

  public void update_contents (bool select_active) {
    // Remove all entries
    unowned var child = this.listbox.get_first_child ();
    while (child != null) {
      unowned var next = child.get_next_sibling ();
      this.listbox.remove (child);
      child = next;
    }

    // Fill the list with address book
    PersonaStore[] eds_stores = Utils.get_eds_address_books (this.contacts_store);
    debug ("Found %d EDS stores", eds_stores.length);

    unowned PersonaStore? local_store = null;
    foreach (unowned var persona_store in eds_stores) {
      if (persona_store.id == "system-address-book") {
        local_store = persona_store;
        continue;
      }

      var source = ((Edsf.PersonaStore) persona_store).source;
      var parent_source = eds_source_registry.ref_source (source.parent);
      var provider_name = Contacts.Utils.format_persona_store_name (persona_store);

      debug ("Contact store \"%s\"", provider_name);

      var source_account_id = "";
      if (parent_source.has_extension (E.SOURCE_EXTENSION_GOA)) {
        var goa_source_ext = parent_source.get_extension (E.SOURCE_EXTENSION_GOA) as E.SourceGoa;
        source_account_id = goa_source_ext.account_id;
      }

      var row = new Adw.ActionRow ();
      row.set_data ("store", persona_store);

      Gtk.Image provider_image;
      if (source_account_id != "")
        provider_image = Contacts.get_icon_for_goa_account (source_account_id);
      else
        provider_image = new Gtk.Image.from_icon_name (Config.APP_ID);
      provider_image.icon_size = Gtk.IconSize.LARGE;
      row.add_prefix (provider_image);
      row.title = provider_name;
      row.subtitle = parent_source.display_name;

      var checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic");
      checkmark.margin_end = 6;
      checkmark.valign = Gtk.Align.CENTER;
      checkmark.halign = Gtk.Align.END;
      checkmark.hexpand = true;
      checkmark.vexpand = true;
      checkmark.visible = (persona_store == this.contacts_store.aggregator.primary_store);
      row.add_suffix (checkmark);
      row.set_activatable_widget (checkmark);
      row.set_data ("checkmark", checkmark);

      this.listbox.append (row);

      if (select_active &&
          persona_store == this.contacts_store.aggregator.primary_store) {
        this.listbox.row_activated (row);
      }
    }

    if (local_store != null) {
      var local_row = new Adw.ActionRow ();
      var provider_image = new Gtk.Image.from_icon_name (Config.APP_ID);
      provider_image.icon_size = Gtk.IconSize.LARGE;
      local_row.add_prefix (provider_image);
      local_row.title = _("Local Address Book");
      var checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic");
      checkmark.margin_end = 6;
      checkmark.valign = Gtk.Align.CENTER;
      checkmark.halign = Gtk.Align.END;
      checkmark.hexpand = true;
      checkmark.vexpand = true;
      checkmark.visible = (local_store == this.contacts_store.aggregator.primary_store);
      local_row.add_suffix (checkmark);
      local_row.set_activatable_widget (checkmark);
      local_row.set_data ("checkmark", checkmark);
      local_row.set_data ("store", local_store);
      this.listbox.append (local_row);
      if (select_active &&
          local_store == this.contacts_store.aggregator.primary_store) {
        this.listbox.row_activated (local_row);
      }
    }
  }
}
