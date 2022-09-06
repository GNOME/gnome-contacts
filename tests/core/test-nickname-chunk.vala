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
  Test.add_func ("/core/nickname-chunk/property_name_chunk", test_property_name);
  Test.add_func ("/core/nickname-chunk/is-empty", test_is_empty);
  Test.add_func ("/core/nickname-chunk/serialize-basic", test_serialize_basic);
  Test.run ();
}

// Make sure that "nickname" maps to a NicknameChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("nickname", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.NicknameChunk);
  assert_true (chunk.property_name == "nickname");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.NicknameChunk) contact.create_chunk ("nickname", null);
  assert_nonnull (chunk);
  assert_true (chunk.is_empty);

  chunk.nickname = "Niels";
  assert_false (chunk.is_empty);

  chunk.nickname = "";
  assert_true (chunk.is_empty);
}

private void test_serialize_basic () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.NicknameChunk) contact.create_chunk ("nickname", null);

  // If the nickname is not set, serialization should give a null result
  var serialized = chunk.to_gvariant ();
  assert_null (serialized);

  // If nickname is set, we should have a variant. We don't need to inspect the
  // variant, we just need to know it properly deserializes
  chunk.nickname = "ndegraef";
  serialized = chunk.to_gvariant ();
  assert_nonnull (serialized);

  var contact2 = new Contacts.Contact.empty ();
  var chunk2 = (Contacts.NicknameChunk) contact2.create_chunk ("nickname", null);
  chunk2.apply_gvariant (serialized);
  assert_true (chunk2.nickname == "ndegraef");
}
