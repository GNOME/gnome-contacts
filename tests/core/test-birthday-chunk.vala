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
  Test.add_func ("/core/birthday-chunk/property_name_chunk", test_property_name);
  Test.add_func ("/core/birthday-chunk/is-empty", test_is_empty);
  Test.add_func ("/core/birthday-chunk/leap-day-birthday", test_leap_day_birthday);
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

void test_leap_day_birthday () {
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