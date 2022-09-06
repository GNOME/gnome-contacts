/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
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
