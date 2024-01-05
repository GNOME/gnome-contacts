/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/core/birthday-chunk/property_name_chunk", test_property_name);
  Test.add_func ("/core/birthday-chunk/is-empty", test_is_empty);
  Test.add_func ("/core/birthday-chunk/leap-day-birthday", test_leap_day_birthday);
  Test.add_func ("/core/birthday-chunk/serialize-basic", test_serialize_basic);
  Test.add_func ("/core/birthday-chunk/serialize-pre-epoch", test_serialize_pre_epoch);
  Test.run ();
}

// Make sure that "birthday" maps to a BirthdayChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("birthday", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.BirthdayChunk);
  assert_true (chunk.property_name == "birthday");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.BirthdayChunk) contact.create_chunk ("birthday", null);
  assert_nonnull (chunk);
  assert_true (chunk.is_empty);

  chunk.birthday = new DateTime.now_utc ();
  assert_false (chunk.is_empty);

  chunk.birthday = null;
  assert_true (chunk.is_empty);
}

private void test_leap_day_birthday () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.BirthdayChunk) contact.create_chunk ("birthday", null);
  assert_nonnull (chunk);
  chunk.birthday = new DateTime.local (2020, 2, 29, 0, 0, 0);

  var leap_day = new DateTime.local (2024, 2, 29, 0, 0, 0);
  assert_true (chunk.is_today (leap_day));

  var feb_28_leap_year = new DateTime.local (2024, 2, 28, 0, 0, 0);
  assert_false (chunk.is_today (feb_28_leap_year));

  var feb_28_non_leap_year = new DateTime.local (2023, 2, 28, 0, 0, 0);
  assert_true (chunk.is_today (feb_28_non_leap_year));
}

private void test_serialize_basic () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.BirthdayChunk) contact.create_chunk ("birthday", null);

  // If the birthday is not set, serialization should give a null result
  var serialized = chunk.to_gvariant ();
  assert_null (serialized);

  // If the birthday is set, we should have a variant. Without checking its
  // contents, it should deserialize in a new contact
  var old_bd = new DateTime.utc (1992, 8, 1, 0, 0, 0);
  chunk.birthday = old_bd;
  serialized = chunk.to_gvariant ();
  assert_nonnull (serialized);

  var contact2 = new Contacts.Contact.empty ();
  var chunk2 = (Contacts.BirthdayChunk) contact2.create_chunk ("birthday", null);
  chunk2.apply_gvariant (serialized);
  assert_true (old_bd.equal (chunk2.birthday));
}

private void test_serialize_pre_epoch () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.BirthdayChunk) contact.create_chunk ("birthday", null);

  // Check that we didn't try to use something that doesn't allow dates before
  // epoch (eg struct tm)
  var old_bd = new DateTime.utc (1961, 7, 3, 0, 0, 0);
  chunk.birthday = old_bd;
  var serialized = chunk.to_gvariant ();
  assert_nonnull (serialized);

  var contact2 = new Contacts.Contact.empty ();
  var chunk2 = (Contacts.BirthdayChunk) contact2.create_chunk ("birthday", null);
  chunk2.apply_gvariant (serialized);
  assert_true (old_bd.equal (chunk2.birthday));
}
