/*
 * Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
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
