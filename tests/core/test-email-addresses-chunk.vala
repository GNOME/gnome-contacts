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
  Test.add_func ("/core/addresses-chunk/property-name-chunk", test_property_name);
  Test.add_func ("/core/addresses-chunk/get-is-empty", test_is_empty);
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
