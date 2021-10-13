/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
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

public class Contacts.LinkOperation : Object, Operation {

  private weak Store store;

  private Gee.LinkedList<Individual> individuals;
  private Gee.HashSet<Gee.HashSet<Persona>> personas_to_link
      = new Gee.HashSet<Gee.HashSet<Persona>> ();

  private bool finished { get; set; default = false; }

  private bool _reversable = false;
  public bool reversable { get { return this._reversable; } }

  private string _description;
  public string description { owned get { return this._description; } }

  public LinkOperation (Store store, Gee.LinkedList<Individual> individuals) {
    this.store = store;
    this.individuals = individuals;

    this._description = ngettext ("Linked %d contact",
                                  "Linked %d contacts", individuals.size)
                        .printf (individuals.size);
  }

  /**
   * Link individuals
   */
  public async void execute () throws GLib.Error {
    var personas_to_link = new Gee.HashSet<Persona> ();
    foreach (var i in individuals) {
      var saved_personas = new Gee.HashSet<Persona> ();
      foreach (var persona in i.personas) {
        personas_to_link.add (persona);
        saved_personas.add (persona);
      }
      this.personas_to_link.add (saved_personas);
    }

    yield this.store.aggregator.link_personas (personas_to_link);
    this._reversable = true;
    notify_property ("reversable");
  }

  /**
   * Undoing means unlinking
   */
  public async void _undo () throws GLib.Error {
    var individual = this.personas_to_link.first_match(() => {return true;})
      .first_match(() => {return true;}).individual;

    yield store.aggregator.unlink_individual (individual);

    foreach (var personas in personas_to_link) {
      yield this.store.aggregator.link_personas (personas);
    }
    this._reversable = false;
    notify_property ("reversable");
  }
}
