/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/core/urls-chunk/property-name-chunk", test_property_name);
  Test.add_func ("/core/urls-chunk/get-absolute-url", test_get_absolute_url);
  Test.add_func ("/core/urls-chunk/get-is-empty", test_is_empty);
  Test.add_func ("/core/urls-chunk/serialize-basic", test_serialize_basic);
  Test.run ();
}

// Make sure that "urls" maps to a UrlsChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("urls", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.UrlsChunk);
  assert_true (chunk.property_name == "urls");
}

private void test_get_absolute_url () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.UrlsChunk) contact.create_chunk ("urls", null);
  assert_nonnull (chunk);
  var url = (Contacts.Url) chunk.get_item (0);

  // Test with a proper scheme attached
  url.raw_url = "https://gnome.org";
  assert_true (url.raw_url == "https://gnome.org");
  assert_true (url.get_absolute_url () == "https://gnome.org");

  // Also if it's not HTTPS
  url.raw_url = "ftp://gnome.org";
  assert_true (url.raw_url == "ftp://gnome.org");
  assert_true (url.get_absolute_url () == "ftp://gnome.org");

  // and if there's no scheme supplied
  url.raw_url = "gnome.org";
  assert_true (url.raw_url == "gnome.org");
  assert_true (url.get_absolute_url () == "https://gnome.org");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.UrlsChunk) contact.create_chunk ("urls", null);
  assert_nonnull (chunk);
  var url = (Contacts.Url) chunk.get_item (0);

  // Even though there is an element, it's empty, so the urls chunk should
  // count as empty too
  assert_true (url.is_empty);
  assert_true (chunk.is_empty);

  url.raw_url = "https://gnome.org";
  assert_false (url.is_empty);
  assert_false (chunk.is_empty);

  url.raw_url = "";
  assert_true (url.is_empty);
  assert_true (chunk.is_empty);
}

private void test_serialize_basic () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.UrlsChunk) contact.create_chunk ("urls", null);

  // If the urls are empty, serialization should give a null result
  var serialized = chunk.to_gvariant ();
  assert_null (serialized);

  // If a url is added, we should have a variant. We don't need to inspect
  // the variant, we just need to know it properly deserializes
  var url = (Contacts.Url) chunk.get_item (0);
  url.raw_url = "https://gnome.org";
  serialized = chunk.to_gvariant ();
  assert_nonnull (serialized);

  var contact2 = new Contacts.Contact.empty ();
  var chunk2 = (Contacts.UrlsChunk) contact2.create_chunk ("urls", null);
  chunk2.apply_gvariant (serialized);
  assert_nonnull (chunk.get_item (0));
  assert_true (((Contacts.Url) chunk.get_item (0)).raw_url == "https://gnome.org");
}
