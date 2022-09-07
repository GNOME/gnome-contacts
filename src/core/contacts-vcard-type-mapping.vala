/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
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
 * The VcardTypeMapping struct is used to map known vcard types to a display
 * name. It also contains the logic when a vard-like type string matches with
 * another.
 */
internal struct Contacts.VcardTypeMapping {
  unowned string name; // untranslated
  unowned string types[3]; //MAX_TYPES
  private const int MAX_TYPES = 3;

  /** Returns whether the mapping contains the given vcard type. */
  public bool contains (string type) {
    for (int i = 0; i < MAX_TYPES && this.types[i] != null; i++)
      if (types_are_equal (this.types[i], type))
        return true;
    return false;
  }

  /**
   * Checks whether all items in the VcardTypeMapping are in the specified @types.
   * Even though there might be other values in @types, we ignore them.
   *
   * For example: [ HOME, FOO, PREF, BLAH ] should match the [ HOME ] VCard
   * type, but not [ HOME, FAX ]
   */
  public bool matches (Gee.Collection<string> types) {
    for (int i = 0; i < MAX_TYPES && this.types[i] != null; i++) {
      bool occurs_in_list = false;
      foreach (var type in types) {
        if (types_are_equal (type, this.types[i])) {
          occurs_in_list = true;
          break;
        }
      }

      if (!occurs_in_list)
        return false;
    }
    return true;
  }

  private static bool types_are_equal (string a, string b) {
    return a.ascii_casecmp (b) == 0;
  }
}
