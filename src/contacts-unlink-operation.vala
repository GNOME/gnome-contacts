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

public class Contacts.UnlinkOperation : Operation {

  private weak Store store;

  private Individual individual;

  private Gee.HashSet<Persona> personas = new Gee.HashSet<Persona> ();

  private bool _reversable = false;
  public override bool reversable { get { return this._reversable; } }

  private string _description;
  public override string description { owned get { return this._description; } }

  public UnlinkOperation (Store store, Individual main) {
    this.store = store;
    this.individual = main;
    this._description = _("Unlinking contacts");
  }

  /* Remove a personas from individual */
  public override async void execute () throws GLib.Error {
    foreach (var persona in this.individual.personas)
      this.personas.add (persona);

    yield store.aggregator.unlink_individual (this.individual);
    this._reversable = true;
    notify_property ("reversable");
  }

  /* Undo the unlinking */
  public override async void _undo () throws GLib.Error {
    yield this.store.aggregator.link_personas (personas);
    this._reversable = false;
    notify_property ("reversable");
  }
}
