/*
 * Copyright (C) 2019 Purism SPC
 *
 * Author: Julian Sparber
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

public class Contacts.AddressbookList : Adw.Bin {

  private BackendStore store;
  private bool show_icon;

  private unowned Gtk.ListBox listbox;
  private AddressbookRow? marked_row = null;

  public signal void addressbook_selected ();

  construct {
    var list_box = new Gtk.ListBox ();
    list_box.row_activated.connect (on_row_activated);
    list_box.set_header_func (list_box_update_header_func);
    this.listbox = list_box;
    this.child = this.listbox;
  }

  public AddressbookList (BackendStore store, bool icon = true) {
    this.store = store;
    this.show_icon = icon;

    this.update ();
  }

  void list_box_update_header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
    if (before == null) {
      row.set_header (null);
    } else if (row.get_header () == null) {
      var header = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
      header.show ();
      row.set_header (header);
    }
  }

  private void on_row_activated (Gtk.ListBox listbox, Gtk.ListBoxRow row) {
    var addressbook = row as AddressbookRow;
    if (addressbook == null)
      return;

    if (this.marked_row != null && this.marked_row == addressbook)
      return;

    if (this.marked_row != null)
      this.marked_row.unselect ();

    addressbook.select ();
    this.marked_row = addressbook;

    addressbook_selected ();
  }

  public void update () {
    // Remove all entries
    unowned var child = this.listbox.get_first_child ();
    while (child != null) {
      unowned var next = child.get_next_sibling ();
      this.listbox.remove (child);
      child = next;
    }

    // Fill the list with address book
    PersonaStore[] eds_stores = Utils.get_eds_address_books_from_backend (this.store);
    debug ("Found %d EDS stores", eds_stores.length);

    PersonaStore? local_store = null;
    foreach (var persona_store in eds_stores) {
      if (persona_store.id == "system-address-book") {
        local_store = persona_store;
        continue;
      }
      var source = ((Edsf.PersonaStore) persona_store).source;
      var parent_source = eds_source_registry.ref_source (source.parent);
      var provider_name = Utils.format_persona_store_name (persona_store);

      debug ("Contact store \"%s\"", provider_name);

      var source_account_id = "";
      if (parent_source.has_extension (E.SOURCE_EXTENSION_GOA)) {
        var goa_source_ext = parent_source.get_extension (E.SOURCE_EXTENSION_GOA) as E.SourceGoa;
        source_account_id = goa_source_ext.account_id;
      }

      Gtk.Image? provider_image = null;
      if (this.show_icon) {
        if (source_account_id != "")
          provider_image = Contacts.get_icon_for_goa_account (source_account_id);
        else
          provider_image = new Gtk.Image.from_icon_name (Config.APP_ID);
      }

      var row = new AddressbookRow (provider_name, parent_source.display_name, provider_image);
      this.listbox.append (row);
    }

    if (local_store != null) {
      var provider_image = this.show_icon? new Gtk.Image.from_icon_name (Config.APP_ID) : null;
      var local_row = new AddressbookRow (_("Local Address Book"), null, provider_image);
      this.listbox.append (local_row);
    }
  }
}

public class Contacts.AddressbookRow : Adw.ActionRow {
  Gtk.Widget checkmark;

  public AddressbookRow (string title, string? subtitle, Gtk.Widget? image = null) {
    this.set_selectable (false);
    if (image != null) {
      this.add_prefix (image);
    }
    this.title = title;
    if (subtitle != null) {
      this.subtitle = subtitle;
    }
    this.checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic");
    this.checkmark.set ("margin-end", 6,
                        "valign", Gtk.Align.CENTER,
                        "halign", Gtk.Align.END,
                        "vexpand", true,
                        "hexpand", true);
    this.set_child (this.checkmark);
  }

  public void unselect () {
    this.checkmark.hide ();
  }

  public void select () {
    this.checkmark.show ();
  }
}
