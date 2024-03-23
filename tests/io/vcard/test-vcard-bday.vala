/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/io/test_vcard_bday_yyyymmdd", test_vcard_bday_yyyymmdd);
  Test.add_func ("/io/test_vcard_bday_yyyy-mm-dd", test_vcard_bday_yyyy_mm_dd);
  Test.add_func ("/io/test_vcard_bday_differen_timezones", test_vcard_bday_different_timezones);
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
  int y, m, d;
  parse_single_contact_bday (VCARD_BDAY_YYYYMMDD,
                             out y, out m, out d);
  if (y != 1992 || m != 8 || d != 1)
    error ("Expected '1992-08-01' but got %d-%d-%d", y, m, d);
}

const string VCARD_BDAY_YYYY_MM_DD =
"""
BEGIN:VCARD
VERSION:3.0
FN:Smith Joe
BDAY;VALUE=date:1957-01-07
END:VCARD
""";

private void test_vcard_bday_yyyy_mm_dd () {
  int y, m, d;
  parse_single_contact_bday (VCARD_BDAY_YYYY_MM_DD,
                             out y, out m, out d);
  if (y != 1957 || m != 1 || d != 7)
    error ("Expected '1957-01-07' but got %d-%d-%d", y, m, d);
}

private void test_vcard_bday_different_timezones () {
  // UTC+12
  if (Environment.set_variable ("TZ", "NZST-12NZDT", true)) {
    int y, m, d;
    parse_single_contact_bday (VCARD_BDAY_YYYY_MM_DD,
                               out y, out m, out d);
    if (y != 1957 || m != 1 || d != 7)
      error ("Expected '1957-01-07' but got %d-%d-%d", y, m, d);
  }
  Environment.unset_variable ("TZ");

  // UTC-11
  if (Environment.set_variable ("TZ", "BST11BDT", true)) {
    int y, m, d;
    parse_single_contact_bday (VCARD_BDAY_YYYY_MM_DD,
                               out y, out m, out d);
    if (y != 1957 || m != 1 || d != 7)
      error ("Expected '1957-01-07' but got %d-%d-%d", y, m, d);
  }
  Environment.unset_variable ("TZ");
}

private void parse_single_contact_bday (string vcard,
                                        out int y, out int m, out int d) {
  var input = new MemoryInputStream.from_data (vcard.data);

  var parser = new Contacts.Io.VCardParser ();
  Contacts.Contact[]? contacts = null;
  try {
    contacts = parser.parse (input);
  } catch (Error err) {
    error ("Error while importing: %s", err.message);
  }

  if (contacts == null)
    error ("no contacts parsed");
  if (contacts.length != 1)
    error ("VCardParser parsed %u elements instead of 1", contacts.length);

  unowned var contact = contacts[0];
  var chunk = contact.get_most_relevant_chunk ("birthday", true);
  if (chunk == null)
    error ("expected 'birthday' chunk to be set, but found none");

  unowned var bday_chunk = (Contacts.BirthdayChunk) chunk;
  if (bday_chunk.birthday == null)
    error ("Found birthday chunk but birthday was null");

  bday_chunk.birthday.get_ymd (out y, out m, out d);
}
