/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
