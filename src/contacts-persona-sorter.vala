/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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
 * A customer sorter that provides a consistent way of sorting
 * {@link Folks.Persona}s within the whole application.
 */
public class Contacts.PersonaSorter : Gtk.Sorter {

  public override Gtk.SorterOrder get_order () {
    return Gtk.SorterOrder.PARTIAL;
  }

  public override Gtk.Ordering compare (Object? item1, Object? item2) {
    unowned var persona_1 = (Persona) item1;
    unowned var persona_2 = (Persona) item2;

    if (persona_1 == persona_2)
      return Gtk.Ordering.EQUAL;

    // Put null persona's last
    if (persona_1 == null || persona_2 == null)
      return (persona_1 == null)? Gtk.Ordering.LARGER : Gtk.Ordering.SMALLER;

    unowned var store_1 = persona_1.store;
    unowned var store_2 = persona_2.store;

    // In the same store, sort Google 'other' contacts last
    if (store_1 == store_2) {
      if (Utils.persona_is_google (persona_1)) {
        var p1_is_other = Utils.persona_is_google_other (persona_1);
        if (p1_is_other != Utils.persona_is_google_other (persona_2))
          return p1_is_other? Gtk.Ordering.LARGER : Gtk.Ordering.SMALLER;
      }

      // Sort on Persona UIDs so we get a consistent sort
      return Gtk.Ordering.from_cmpfunc (strcmp (persona_1.uid, persona_2.uid));
    }

    // Sort primary stores before others
    if (store_1.is_primary_store != store_2.is_primary_store)
      return (store_1.is_primary_store)? Gtk.Ordering.SMALLER : Gtk.Ordering.LARGER;

    // E-D-S stores get prioritized next
    if ((store_1.type_id == "eds") != (store_2.type_id == "eds"))
      return (store_1.type_id == "eds")? Gtk.Ordering.SMALLER : Gtk.Ordering.LARGER;

    // Normal case: use alphabetical sorting
    return Gtk.Ordering.from_cmpfunc (strcmp (store_1.id, store_2.id));
  }
}
