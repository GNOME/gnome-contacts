/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A ImportOperation takes an array of serialized contacts (represented by
 * {@link GLib.HashTable}s) which can then be imported using
 * {@link Folks.PersonaStore.add_persona_from_details}.
 */
public class Contacts.ImportOperation : Operation {

  public override bool reversable { get { return false; } }

  private string _description;
  public override string description { owned get { return this._description; } }

  public ListModel to_import { get; construct set; }

  public Store store { get; construct set; }

  construct {
    this._description = ngettext ("Imported %u contact",
                                  "Imported %u contacts",
                                  to_import.get_n_items ())
        .printf (to_import.get_n_items ());
  }

  public ImportOperation (Store store, ListModel to_import) {
    Object (store: store, to_import: to_import);
  }

  public override async void execute () throws GLib.Error {
    unowned var primary_store = this.store.aggregator.primary_store;
    debug ("Importing %u contacts to primary store '%s'",
           this.to_import.get_n_items (), primary_store.display_name);

    uint new_count = 0;
    for (uint i = 0; i < this.to_import.get_n_items (); i++) {
      var contact = (Contact) this.to_import.get_item (i);

      var individual = yield contact.apply_changes (primary_store);
      if (individual != null) {
        debug ("Created new individual (%s)",
               (individual != null)? individual.id : "null");
        new_count++;
      } else {
        debug ("Added persona; no new created");
      }
    }

    debug ("Done importing; got %u new contacts", new_count);
  }

  public override async void _undo () throws GLib.Error {
    throw new IOError.NOT_SUPPORTED ("Undoing an import operation is not supported");
  }
}
