/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
