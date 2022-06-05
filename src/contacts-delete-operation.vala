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
 * A DeleteOperation permanently deletes contacts. Note that this is an
 * irreversible operation, so to prevent accidents, it allows you to set a
 * timeout period during which you can cancel the operation still.
 */
public class Contacts.DeleteOperation : Operation {

  private Gee.List<Individual> individuals;

  public override bool reversable { get { return false; } }

  private string _description;
  public override string description { owned get { return this._description; } }

  public DeleteOperation (Gee.List<Individual> individuals) {
    this.individuals = individuals;
    this._description = ngettext ("Deleting %d contact",
                                  "Deleting %d contacts", individuals.size)
                        .printf (individuals.size);
  }

  /**
   * Delete individuals
   */
  public override async void execute () throws GLib.Error {
    foreach (var indiv in this.individuals) {
      debug ("Removing individual '%s'", indiv.display_name);

      foreach (var persona in indiv.personas) {
        // TODO: make sure it is actually removed
        yield persona.store.remove_persona (persona);
      }
    }
  }

  protected override async void _undo () throws GLib.Error {
    // No need to do anything, since reversable is true
  }
}
