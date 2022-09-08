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
  Test.add_func ("/core/urls-chunk/property_name_chunk", test_property_name);
  Test.add_func ("/core/urls-chunk/get_absolute_url", test_get_absolute_url);
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
