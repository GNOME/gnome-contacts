/*
 * Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A subclass of {@link Gtk.Sorter} which sorts {@link Folks.Individual}s into
 * sections (for example "Favorites").
 */
public class Contacts.IndividualSectionSorter : Gtk.Sorter {

  public IndividualSectionSorter () {
  }

  public override Gtk.Ordering compare (Object? item1, Object? item2) {
    unowned var a = item1 as Individual;
    if (a == null)
      return Gtk.Ordering.SMALLER;

    unowned var b = item2 as Individual;
    if (b == null)
      return Gtk.Ordering.LARGER;

    // Always prefer favourites over non-favourites.
    if (a.is_favourite != b.is_favourite)
      return a.is_favourite? Gtk.Ordering.SMALLER : Gtk.Ordering.LARGER;

    return Gtk.Ordering.EQUAL;
  }

  public override Gtk.SorterOrder get_order () {
    return Gtk.SorterOrder.PARTIAL;
  }
}
