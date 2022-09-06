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

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/core/phones-chunk/property-name-chunk", test_property_name);
  Test.add_func ("/core/phones-chunk/get-is-empty", test_is_empty);
  Test.add_func ("/core/phones-chunk/serialize-basic", test_serialize_basic);
  Test.run ();
}

// Make sure that "phones" maps to a PhonesChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("phone-numbers", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.PhonesChunk);
  assert_true (chunk.property_name == "phone-numbers");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.PhonesChunk) contact.create_chunk ("phone-numbers", null);
  assert_nonnull (chunk);
  var phone = (Contacts.Phone) chunk.get_item (0);

  // Even though there is an element, it's empty, so the phones chunk should
  // count as empty too
  assert_true (phone.is_empty);
  assert_true (chunk.is_empty);

  phone.raw_number = "+321245678";
  assert_false (phone.is_empty);
  assert_false (chunk.is_empty);

  phone.raw_number = "";
  assert_true (phone.is_empty);
  assert_true (chunk.is_empty);
}

private void test_serialize_basic () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.PhonesChunk) contact.create_chunk ("phone-numbers", null);

  // If the phones are empty, serialization should give a null result
  var serialized = chunk.to_gvariant ();
  assert_null (serialized);

  // If a phone is added, we should have a variant. We don't need to inspect
  // the variant, we just need to know it properly deserializes
  var phone = (Contacts.Phone) chunk.get_item (0);
  phone.raw_number = "+321234567";
  serialized = chunk.to_gvariant ();
  assert_nonnull (serialized);

  var contact2 = new Contacts.Contact.empty ();
  var chunk2 = (Contacts.PhonesChunk) contact2.create_chunk ("phone-numbers", null);
  chunk2.apply_gvariant (serialized);
  assert_nonnull (chunk.get_item (0));
  assert_true (((Contacts.Phone) chunk.get_item (0)).raw_number == "+321234567");
}
