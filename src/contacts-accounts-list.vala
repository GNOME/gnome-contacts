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

/**
 * The AccountsList widget provides a way to list all the known address books
 * for a user, as well as providing a means of selecting a "primary" address
 * book, ie the address book that will be used to write the details of a
 * contact to.
 *
 * Internally, each "address book" is a {@link Folks.PersonaStore}.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-accounts-list.ui")]
public class Contacts.AccountsList : Adw.Bin {

  [GtkChild]
  private unowned Gtk.ListBox listbox;

  private Gtk.SingleSelection selection;

  /** The selected PersonaStore (or null if none) */
  public PersonaStore? selected_store {
    get { return (PersonaStore) this.selection.selected_item; }
  }

  public AccountsList (Store contacts_store) {
    // We only list E-D-S address books here, so make a filter model
    var filter = new Gtk.CustomFilter ((item) => {
      unowned var store = (PersonaStore) item;
      return store.type_id == "eds";
    });
    var model = new Gtk.FilterListModel (contacts_store.address_books,
                                         (owned) filter);

    // Setup the selection model
    this.selection = new Gtk.SingleSelection (model);

    // Update the row when the selection model changes
    this.selection.selection_changed.connect ((sel, pos, n_items) => {
      for (uint i = pos; i < pos + n_items; i++) {
        var row = (AddressbookRow?) this.listbox.get_row_at_index ((int) i);
        if (row != null)
          row.selected = this.selection.is_selected (i);
      }
      notify_property ("selected-store");
    });

    // Now bind the listbox to it
    this.listbox.bind_model (model, (item) => {
      unowned var persona_store = (PersonaStore) item;
      var row = new AddressbookRow (persona_store);

      // Update the selection model when the row is activated
      row.activated.connect ((row) => {
        this.selection.set_selected ((uint) row.get_index ());
      });

      return row;
    });

    // Initially, the primary store (if set) is selected
    for (uint i = 0; i < model.get_n_items (); i++) {
      var persona_store = (PersonaStore) model.get_item (i);
      if (persona_store == contacts_store.aggregator.primary_store)
        this.selection.set_selected (i);
    }
  }

  private class AddressbookRow : Adw.ActionRow {

    public PersonaStore persona_store { get; construct set; }

    public bool selected { get; set; default = false; }

    construct {
      var source = ((Edsf.PersonaStore) this.persona_store).source;
      var parent_source = eds_source_registry.ref_source (source.parent);

      debug ("Contact store \"%s\"",
             Utils.format_persona_store_name (this.persona_store));

      // Image
      var source_account_id = "";
      if (parent_source.has_extension (E.SOURCE_EXTENSION_GOA)) {
        var goa_source_ext = parent_source.get_extension (E.SOURCE_EXTENSION_GOA) as E.SourceGoa;
        source_account_id = goa_source_ext.account_id;
      }
      Gtk.Image provider_image;
      if (this.persona_store.id != "system-address-book" && source_account_id != "")
        provider_image = Contacts.get_icon_for_goa_account (source_account_id);
      else
        provider_image = new Gtk.Image.from_icon_name (Config.APP_ID);
      provider_image.icon_size = Gtk.IconSize.LARGE;
      add_prefix (provider_image);

      // Title - subtitle
      this.title = Utils.format_persona_store_name (this.persona_store);
      this.subtitle = parent_source.display_name;

      // Checkmark
      var checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic");
      bind_property ("selected", checkmark, "visible", BindingFlags.SYNC_CREATE);
      add_suffix (checkmark);
      set_activatable_widget (checkmark);
    }

    public AddressbookRow (PersonaStore persona_store) {
      Object (persona_store: persona_store);
    }
  }
}
