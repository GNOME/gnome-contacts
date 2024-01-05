/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/utils/get_first", Contacts.UtilsTests.get_first);
  Test.run ();
}

namespace Contacts.UtilsTests {
  private void get_first () {
    Gee.Collection<Object> empty = Gee.Collection.empty ();
    assert_true (Utils.get_first (empty) == null);
  }
}
