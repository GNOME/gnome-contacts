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

namespace Contacts.Tests.Io {

  // Helper to serialize and deserialize an AbstractFieldDetails
  public T _transform_single_afd<T> (string prop_key, T afd) {
    Gee.Set<T> afd_set = new Gee.HashSet<T> ();
    afd_set.add (afd);

    Value val = Value (typeof (Gee.Set));
    val.set_object (afd_set);

    Value emails_value = _transform_single_value (prop_key, val);
    var emails_set = emails_value.get_object () as Gee.Set<T>;
    if (emails_set == null)
      error ("GValue has null value");
    if (emails_set.size != 1)
      error ("Expected %d elements but got %d", 1, emails_set.size);

    var deserialized_fd = Utils.get_first<T> (emails_set);
    assert_nonnull (deserialized_fd);

    return deserialized_fd;
  }

  // Helper to serialize and deserialize a single property with a GLib.Value
  public GLib.Value _transform_single_value (string prop_key, GLib.Value val) {
    var details = new HashTable<string, Value?> (GLib.str_hash, GLib.str_equal);
    details.insert (prop_key, val);

    // Serialize
    Variant serialized = Contacts.Io.serialize_to_gvariant_single (details);
    if (serialized == null)
      error ("Couldn't serialize single-value table for property %s", prop_key);

    // Deserialize
    var details_deserialized = Contacts.Io.deserialize_gvariant_single (serialized);
    if (details_deserialized == null)
      error ("Couldn't deserialize details for property %s", prop_key);

    if (!details_deserialized.contains (prop_key))
      error ("Deserialized details doesn't contain value for property %s", prop_key);
    Value? val_deserialized = details_deserialized.lookup (prop_key);
    if (val_deserialized.type() == GLib.Type.NONE)
      error ("Deserialized Value is unset");

    return val_deserialized;
  }
}
