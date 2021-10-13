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

public class Contacts.DeleteOperation : Object, Operation {

  private Gee.List<Individual> individuals;

  // We don't support reversing a removal. What we do instead, is put a timeout
  // before actually executing this operation so the user has time to change
  // their mind.
  public bool reversable { get { return false; } }

  private string _description;
  public string description { owned get { return this._description; } }

  public DeleteOperation (Gee.List<Individual> individuals) {
    this.individuals = individuals;
    this._description = ngettext ("Deleting %d contact",
                                  "Deleting %d contacts", individuals.size)
                        .printf (individuals.size);
  }

  /**
   * Link individuals
   */
  public async void execute () throws GLib.Error {
    foreach (var indiv in this.individuals) {
      foreach (var persona in indiv.personas) {
        // TODO: make sure it is actually removed
        yield persona.store.remove_persona (persona);
      }
    }
  }

  // See comments near the reversable property
  protected async void _undo () throws GLib.Error {
    throw new GLib.IOError.NOT_SUPPORTED ("Undoing not supported");
  }
}
