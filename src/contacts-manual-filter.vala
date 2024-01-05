/*
 * Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A subclass of {@link Gtk.Filter} which hides a programmatically chosen set
 * of individuals. The main use case here is to temporarily hide individuals
 * that are going to be deleted soon.
 */
public class Contacts.ManualFilter : Gtk.Filter {

  // There's not too much of a point in optimizing this, as the main case is
  // hiding a handful of individuals that are about to deleted
  private GenericArray<unowned Individual> hidden = new GenericArray<unowned Individual> ();

  /**
   * Marks that the given individual should to be hidden
   */
  public void add_individual (Individual individual) {
    this.hidden.add (individual);
    changed (Gtk.FilterChange.MORE_STRICT);
  }

  /**
   * Marks that the given individual should no longer to be hidden
   */
  public void remove_individual (Individual individual)
      requires (this.hidden.find (individual)) {
    this.hidden.remove (individual);
    changed (Gtk.FilterChange.LESS_STRICT);
  }

  public override bool match (Object? item)
      requires (item is Individual) {
    return !this.hidden.find((Individual) item);
  }

  public override Gtk.FilterMatch get_strictness () {
    if (this.hidden.length == 0)
      return Gtk.FilterMatch.ALL;

    return Gtk.FilterMatch.SOME;
  }
}
