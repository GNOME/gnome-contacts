/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

public class Contacts.LinkOperation : Operation {

  private weak Store store;

  private Gee.LinkedList<Individual> individuals;
  private Gee.HashSet<Gee.HashSet<Persona>> personas_to_link
      = new Gee.HashSet<Gee.HashSet<Persona>> ();

  private bool _reversable = false;
  public override bool reversable { get { return this._reversable; } }

  private string _description;
  public override string description { owned get { return this._description; } }

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
  public override async void execute () throws GLib.Error {
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
  public override async void _undo () throws GLib.Error {
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
