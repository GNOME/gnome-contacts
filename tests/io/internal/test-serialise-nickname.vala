/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
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

using Folks;

void main (string[] args) {
  Test.init (ref args);
  Test.add_func ("/io/serialize_nickame",
                 Contacts.Tests.Io.test_serialize_nickname);
  Test.run ();
}

namespace Contacts.Tests.Io {

  private void test_serialize_nickname () {
    unowned var nick_key = PersonaStore.detail_key (PersonaDetail.NICKNAME);

    string old_nick = "nielsdg";
    var old_nick_val = Value (typeof (string));
    old_nick_val.set_string (old_nick);

    var new_nick_val = _transform_single_value (nick_key, old_nick_val);
    assert_true (new_nick_val.type () == typeof (string));
    assert_true (old_nick == new_nick_val.get_string ());
  }
}
