/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/core/notes-chunk/property-name-chunk", test_property_name);
  Test.add_func ("/core/notes-chunk/get-is-empty", test_is_empty);
  Test.run ();
}

// Make sure that "notes" maps to a NotesChunk
private void test_property_name () {
  var contact = new Contacts.Contact.empty ();

  var chunk = contact.create_chunk ("notes", null);
  assert_nonnull (chunk);
  assert_true (chunk is Contacts.NotesChunk);
  assert_true (chunk.property_name == "notes");
}

private void test_is_empty () {
  var contact = new Contacts.Contact.empty ();
  var chunk = (Contacts.NotesChunk) contact.create_chunk ("notes", null);
  assert_nonnull (chunk);
  var note = (Contacts.Note) chunk.get_item (0);

  // Even though there is an element, it's empty, so the notes chunk should
  // count as empty too
  assert_true (note.is_empty);
  assert_true (chunk.is_empty);

  note.text = "This is a note";
  assert_false (note.is_empty);
  assert_false (chunk.is_empty);

  // Only whitespace should still count as empty
  note.text = "    ";
  assert_true (note.is_empty);
  assert_true (chunk.is_empty);
}
