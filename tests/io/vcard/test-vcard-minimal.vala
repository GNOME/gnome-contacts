/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/io/test_vcard_minimal", test_vcard_minimal);
  Test.run ();
}

const string VCARD_MINIMAL =
"""
BEGIN:VCARD
VERSION:3.0
FN:Niels De Graef
END:VCARD
""";

private void test_vcard_minimal () {
  var input = new MemoryInputStream.from_data (VCARD_MINIMAL.data);

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
  var chunk = contact.get_most_relevant_chunk ("full-name", true);
  assert_nonnull (chunk);

  unowned var fn_chunk = (Contacts.FullNameChunk) chunk;
  if (fn_chunk.full_name != "Niels De Graef")
    error ("Expected '%s' but got '%s'", "Niels De Graef", fn_chunk.full_name);
}
