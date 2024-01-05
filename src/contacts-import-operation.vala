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

  private Contact[] to_import;

  private unowned Store store;

  public override bool reversable { get { return false; } }

  private string _description;
  public override string description { owned get { return this._description; } }

  public ImportOperation (Store store, Contact[] to_import) {
    this.to_import = to_import;
    this.store = store;

    this._description = ngettext ("Imported %u contact",
                                  "Imported %u contacts",
                                  to_import.length).printf (to_import.length);
  }

  public override async void execute () throws GLib.Error {
    unowned var primary_store = this.store.aggregator.primary_store;
    debug ("Importing %u contacts to primary store '%s'",
           this.to_import.length, primary_store.display_name);

    uint new_count = 0;
    foreach (unowned var contact in this.to_import) {
      unowned var individual =
          yield contact.apply_changes (this.store.aggregator.primary_store);
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
    return_if_reached ();
  }
}
