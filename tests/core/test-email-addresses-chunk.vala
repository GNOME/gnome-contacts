/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/core/email-addresses-chunk/property-name-chunk", test_property_name);
  Test.add_func ("/core/email-addresses-chunk/get-is-empty", test_is_empty);
  Test.add_func ("/core/email-addresses-chunk/serialize-basic", test_serialize_basic);
  Test.run ();
}

// Make sure that "email-addresses" maps to a UrlsChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("email-addresses", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.EmailAddressesChunk);
  assert_true (chunk.property_name == "email-addresses");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.EmailAddressesChunk) contact.create_chunk ("email-addresses", null);
  assert_nonnull (chunk);
  var address = (Contacts.EmailAddress) chunk.get_item (0);

  // Even though there is an element, it's empty, so the urls chunk should
  // count as empty too
  assert_true (address.is_empty);
  assert_true (chunk.is_empty);

  address.raw_address = "neo@matrix.com";
  assert_false (address.is_empty);
  assert_false (chunk.is_empty);

  address.raw_address = "";
  assert_true (address.is_empty);
  assert_true (chunk.is_empty);
}

private void test_serialize_basic () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.EmailAddressesChunk) contact.create_chunk ("email-addresses", null);

  // If the emailaddresss are empty, serialization should give a null result
  var serialized = chunk.to_gvariant ();
  assert_null (serialized);

  // If a email address is added, we should have a variant. We don't need to
  // inspect the variant, we just need to know it properly deserializes
  var email_addr = (Contacts.EmailAddress) chunk.get_item (0);
  email_addr.raw_address = "nielsdegraef@gmail.com";
  serialized = chunk.to_gvariant ();
  assert_nonnull (serialized);

  var contact2 = new Contacts.Contact.empty ();
  var chunk2 = (Contacts.EmailAddressesChunk) contact2.create_chunk ("email-addresses", null);
  chunk2.apply_gvariant (serialized);
  assert_nonnull (chunk.get_item (0));
  assert_true (((Contacts.EmailAddress) chunk.get_item (0)).raw_address == "nielsdegraef@gmail.com");
}
