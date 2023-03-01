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
  Test.add_func ("/core/addresses-chunk/to-maps-uri", test_to_maps_uri);
  Test.run ();
}

// Make sure that "postal-addresses" maps to a UrlsChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("postal-addresses", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.AddressesChunk);
  assert_true (chunk.property_name == "postal-addresses");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.AddressesChunk) contact.create_chunk ("postal-addresses", null);
  assert_nonnull (chunk);
  var address = (Contacts.Address) chunk.get_item (0);

  // Even though there is an element, it's empty, so the urls chunk should
  // count as empty too
  assert_true (address.is_empty);
  assert_true (chunk.is_empty);

  // Make sure that the notify works correctly for the address too
  bool notified = false;
  address.notify["is-empty"].connect ((o, p) => { notified = true; });

  address.address.street = "Yellow brick road";
  assert_false (address.is_empty);
  assert_false (chunk.is_empty);
  assert_true (notified);

  address.address.street = "";
  assert_true (address.is_empty);
  assert_true (chunk.is_empty);
}

private void test_to_maps_uri () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.AddressesChunk) contact.create_chunk ("postal-addresses", null);
  assert_nonnull (chunk);
  var address = (Contacts.Address) chunk.get_item (0);

  address.address.street = "Yellow brick road";
  assert_true (address.to_maps_uri() == "maps:q=Yellow%20brick%20road");
}
