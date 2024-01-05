/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/core/roles-chunk/property-name-chunk", test_property_name);
  Test.add_func ("/core/roles-chunk/get-is-empty", test_is_empty);
  Test.run ();
}

// Make sure that "roles" maps to a RolesChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("roles", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.RolesChunk);
  assert_true (chunk.property_name == "roles");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.RolesChunk) contact.create_chunk ("roles", null);
  assert_nonnull (chunk);
  var orgrole = (Contacts.OrgRole) chunk.get_item (0);

  // Even though there is an element, it's empty, so the roles chunk should
  // count as empty too
  assert_true (orgrole.is_empty);
  assert_true (chunk.is_empty);

  orgrole.role.organisation_name = "GNOME";
  assert_false (orgrole.is_empty);
  assert_false (chunk.is_empty);

  orgrole.role.organisation_name = "";
  assert_true (orgrole.is_empty);
  assert_true (chunk.is_empty);
}
