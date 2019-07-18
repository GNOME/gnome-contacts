/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
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

using Gtk;
using Folks;
using Gee;

namespace Contacts {
  public class LinkOperation : Object {
    private weak Store store;
    private HashSet<HashSet<Persona>> personas_to_link;
    private bool finished { get; set; default = false; }

    public LinkOperation(Store store) {
      this.store = store;
      this.personas_to_link = new HashSet<HashSet<Persona>> ();
    }

    /* Link individuals */
    public async void do (LinkedList<Individual> individuals) {
      var personas_to_link = new HashSet<Persona> ();
      foreach (var i in individuals) {
        var saved_personas = new HashSet<Persona> ();
        foreach (var persona in i.personas) {
          personas_to_link.add (persona);
          saved_personas.add (persona);
        }
        this.personas_to_link.add (saved_personas);
      }

      // We don't need to unlink the individuals because we are using every persona
      yield link_personas(this.store, this.store.aggregator, personas_to_link);

      finished = true;
    }

    /* Undo the linking */
    public async void undo () {
      var individual = this.personas_to_link.first_match(() => {return true;})
        .first_match(() => {return true;}).individual;
      yield store.aggregator.unlink_individual (individual);
      foreach (var personas in personas_to_link) {
        yield link_personas (this.store, this.store.aggregator, personas);
      }
    }
  }

  public class UnLinkOperation : Object {
    private weak Store store;
    public UnLinkOperation(Store store) {
      this.store = store;
    }

    /* Remove a personas from individual */
    public async void do (Individual main, Set<Persona> personas_to_remove) {
      var personas_to_keep = new HashSet<Persona> ();
      foreach (var persona in main.personas)
        if (!personas_to_remove.contains (persona))
          personas_to_keep.add (persona);

      try {
        yield store.aggregator.unlink_individual (main);
      } catch (Error e) {
        debug ("Couldn't link personas");
      }
      yield link_personas(this.store, this.store.aggregator, personas_to_keep);
    }

    /* Undo the unlinking */
    public async void undo () {
    }
  }

 /* Workaround: link_personas creates a new persona in the primary-store,
  * For some reason we can't change the primary-store directly,
  * but we can change the gsettings property.
  * Before linking we set the primary-store to be "key-file"
  * that the linking persona isn't written to a real store
  */
  private async void link_personas (Store store, IndividualAggregator aggregator, Set<Persona> personas) {
    var settings = new GLib.Settings ("org.freedesktop.folks");
    var default_store = settings.get_string ("primary-store");
    settings.set_string ("primary-store", "key-file:relationships.ini");
    try {
      yield aggregator.link_personas (personas);
    } catch (Error e) {
      debug ("%s", e.message);
    }

    // Rest primary-store
    settings.set_string ("primary-store", default_store);
  }
}
