/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/io/test_vcard_bday_yyyymmdd", test_vcard_bday_yyyymmdd);
  Test.run ();
}

const string VCARD_BDAY_YYYYMMDD =
"""
BEGIN:VCARD
VERSION:3.0
FN:Niels De Graef
BDAY:19920801
END:VCARD
""";

private void test_vcard_bday_yyyymmdd () {
  var input = new MemoryInputStream.from_data (VCARD_BDAY_YYYYMMDD.data);

  var parser = new Contacts.Io.VCardParser ();
  Contacts.Contact[]? contacts = null;
  try {
    contacts = parser.parse (input);
  } catch (Error err) {
    error ("Error while importing: %s", err.message);
  }

  assert_nonnull (contacts);
  if (contacts.length != 1)
    error ("VCardParser parsed %u elements instead of 1", contacts.length);

  unowned var contact = contacts[0];
  var chunk = contact.get_most_relevant_chunk ("birthday", true);
  assert_nonnull (chunk);

  unowned var bday_chunk = (Contacts.BirthdayChunk) chunk;
  assert_nonnull (bday_chunk.birthday);

  int y, m, d;
  bday_chunk.birthday.get_ymd (out y, out m, out d);
  if (y != 1992 || m != 8 || d != 1)
    error ("Expected '1992-08-01' but got %d-%d-%d", y, m, d);
}
