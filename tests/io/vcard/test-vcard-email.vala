/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/io/test_vcard_single_email", test_vcard_single_email);
  Test.add_func ("/io/test_vcard_multiple_email", test_vcard_multiple_email);
  Test.run ();
}

const string VCARD_SINGLE_EMAIL =
"""
BEGIN:VCARD
VERSION:3.0
FN:Niels De Graef
EMAIL;TYPE=HOME:nielsdegraef@gmail.com
END:VCARD
""";

private void test_vcard_single_email () {
  var input = new MemoryInputStream.from_data (VCARD_SINGLE_EMAIL.data);

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
  var chunk = contact.get_most_relevant_chunk ("email-addresses", true);
  assert_nonnull (chunk);

  unowned var emails_chunk = (Contacts.EmailAddressesChunk) chunk;
  var email_addr = (Contacts.EmailAddress) emails_chunk.get_item (0);
  if (email_addr.raw_address != "nielsdegraef@gmail.com")
    error ("Expected nielsdegraef@gmail.com but got '%s'",
           email_addr.raw_address);
}

const string VCARD_MULTIPLE_EMAIL =
"""
BEGIN:VCARD
VERSION:3.0
FN:Niels De Graef
EMAIL;TYPE=HOME:nielsdegraef@gmail.com
EMAIL;TYPE=WORK:ndegraef@redhat.com
END:VCARD
""";

private void test_vcard_multiple_email () {
  var input = new MemoryInputStream.from_data (VCARD_MULTIPLE_EMAIL.data);

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
  var chunk = contact.get_most_relevant_chunk ("email-addresses", true);
  assert_nonnull (chunk);

  unowned var emails_chunk = (Contacts.EmailAddressesChunk) chunk;

  // First email address
  var email_addr1 = (Contacts.EmailAddress) emails_chunk.get_item (0);
  if (email_addr1.raw_address != "nielsdegraef@gmail.com")
    error ("Expected nielsdegraef@gmail.com but got '%s'",
           email_addr1.raw_address);

  // Second email address
  var email_addr2 = (Contacts.EmailAddress) emails_chunk.get_item (1);
  if (email_addr2.raw_address != "ndegraef@redhat.com")
    error ("Expected ndegraef@redhat.com but got '%s'",
           email_addr2.raw_address);
}
