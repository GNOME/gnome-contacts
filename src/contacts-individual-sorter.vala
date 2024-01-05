/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A subclass of {@link Gtk.Sorter} which sorts {@link Folks.Individual}s.
 */
public class Contacts.IndividualSorter : Gtk.Sorter {

  private bool sort_on_surname = false;

  public IndividualSorter (GLib.Settings settings) {
    this.sort_on_surname = settings.get_boolean ("sort-on-surname");
    settings.changed["sort-on-surname"].connect (() => {
      this.sort_on_surname = settings.get_boolean ("sort-on-surname");
      this.changed (Gtk.SorterChange.DIFFERENT);
    });
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

    // Both are (non-)favourites: sort by either first name or surname (user preference)
    unowned var a_name = this.sort_on_surname? try_get_surname (a) : a.display_name;
    unowned var b_name = this.sort_on_surname? try_get_surname (b) : b.display_name;

    int names_cmp = a_name.collate (b_name);
    if (names_cmp != 0)
      return Gtk.Ordering.from_cmpfunc (names_cmp);

    // Since we want total ordering, compare uuids as a last resort
    return Gtk.Ordering.from_cmpfunc (strcmp (a.id, b.id));
  }

  private unowned string try_get_surname (Individual indiv) {
    if (indiv.structured_name != null && indiv.structured_name.family_name != "")
      return indiv.structured_name.family_name;

    // Fall back to the display_name
    return indiv.display_name;
  }

  public override Gtk.SorterOrder get_order () {
    return Gtk.SorterOrder.TOTAL;
  }
}
