/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
