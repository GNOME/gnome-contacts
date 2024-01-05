/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/core/full-name-chunk/property_name_chunk", test_property_name);
  Test.add_func ("/core/full-name-chunk/is-empty", test_is_empty);
  Test.add_func ("/core/full-name-chunk/serialize-basic", test_serialize_basic);
  Test.run ();
}

// Make sure that "full-name" maps to a FullNameChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("full-name", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.FullNameChunk);
  assert_true (chunk.property_name == "full-name");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.FullNameChunk) contact.create_chunk ("full-name", null);
  assert_nonnull (chunk);
  assert_true (chunk.is_empty);

  chunk.full_name = "Niels De Graef";
  assert_false (chunk.is_empty);

  chunk.full_name = "";
  assert_true (chunk.is_empty);
}

private void test_serialize_basic () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.FullNameChunk) contact.create_chunk ("full-name", null);

  // If the full name is not set, serialization should give a null result
  var serialized = chunk.to_gvariant ();
  assert_null (serialized);

  // If full name is set, we should have a variant. We don't need to inspect
  // the variant, we just need to know it properly deserializes
  chunk.full_name = "Niels De Graef";
  serialized = chunk.to_gvariant ();
  assert_nonnull (serialized);

  var contact2 = new Contacts.Contact.empty ();
  var chunk2 = (Contacts.FullNameChunk) contact2.create_chunk ("full-name", null);
  chunk2.apply_gvariant (serialized);
  assert_true (chunk2.full_name == "Niels De Graef");
}
