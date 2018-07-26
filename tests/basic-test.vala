/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
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

using Gee;

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/utils/get_first", Contacts.UtilsTests.get_first);
  Test.run ();
}

namespace Contacts.UtilsTests {
  private void get_first () {
    Collection<Object> empty = Collection.empty ();
    assert_true (Utils.get_first (empty) == null);
  }
}
