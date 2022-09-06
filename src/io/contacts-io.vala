/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
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
 * Everything in the Io namespace deals with importing and exporting contacts,
 * both internally (between Contacts and a subprocess, using {@link GLib.Variant}
 * serialization) and externally (VCard, CSV, ...).
 */
namespace Contacts.Io {

  /**
   * Serializes a list of {@link Contact}s as returned by a
   * {@link Contacts.Io.Parser} into a {@link GLib.Variant} so it can be sent
   * from one process to another.
   */
  public GLib.Variant serialize_to_gvariant (Contacts.Contact[]? contacts) {
    var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));

    foreach (unowned var contact in contacts) {
      var variant = contact.to_gvariant ();
      if (variant.n_children () == 0)
        continue;
      builder.add_value (variant);
    }

    return builder.end ();
  }

  /**
   * Deserializes the {@link GLib.Variant} back into a list of
   * {@link Contacts.Contact}s.
   */
  public Contacts.Contact[] deserialize_gvariant (Variant variant)
      requires (variant.get_type ().equal (new VariantType ("aa{sv}"))) {

    var result = new GenericArray<Contacts.Contact> ();

    var iter = variant.iterator ();
    GLib.Variant element;
    while (iter.next ("@a{sv}", out element)) {
      var contact = new Contact.for_gvariant (element);
      result.add (contact);
    }

    return result.steal ();
  }
}
