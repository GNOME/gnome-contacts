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
 * A custom sorter that provides a consistent way of sorting
 * {@link Folks.AbstractFieldDetails} within the whole application.
 */
public class Contacts.AbstractFieldDetailsSorter : Gtk.Sorter {

  public override Gtk.SorterOrder get_order () {
    return Gtk.SorterOrder.PARTIAL;
  }

  public override Gtk.Ordering compare (Object? item1, Object? item2) {
    unowned var a = (AbstractFieldDetails) item1;
    unowned var b = (AbstractFieldDetails) item2;

    // Fields with a PREF hint always go first (see VCard PREF attribute)
    var a_has_pref = has_pref (a);
    if (a_has_pref != has_pref (b))
      return (a_has_pref)? Gtk.Ordering.SMALLER : Gtk.Ordering.LARGER;

    // sort by field type first (e.g. "Home", "Work")
    unowned var type_set = select_typeset_from_fielddetails (a);
    var result = type_set.format_type (a).ascii_casecmp (type_set.format_type (b));
    if (result != 0)
      return Gtk.Ordering.from_cmpfunc (result);

    // Try to compare by value if types are equal
    unowned var aa = a as AbstractFieldDetails<string>;
    unowned var bb = b as AbstractFieldDetails<string>;
    if (aa != null && bb != null)
      return Gtk.Ordering.from_cmpfunc (strcmp (aa.value, bb.value));

    // No heuristics to fall back to.
    warning ("Unsupported AbstractFieldDetails value type");
    return Gtk.Ordering.EQUAL;
  }

  private bool has_pref (AbstractFieldDetails details) {
    var evolution_pref = details.get_parameter_values ("x-evolution-ui-slot");
    if (evolution_pref != null && Utils.get_first (evolution_pref) == "1")
      return true;

    foreach (var param in details.parameters["type"]) {
      if (param.ascii_casecmp ("PREF") == 0)
        return true;
    }
    return false;
  }

  private unowned TypeSet select_typeset_from_fielddetails (AbstractFieldDetails a) {
    if (a is EmailFieldDetails)
      return TypeSet.email;
    if (a is PhoneFieldDetails)
      return TypeSet.phone;
    return TypeSet.general;
  }
}
