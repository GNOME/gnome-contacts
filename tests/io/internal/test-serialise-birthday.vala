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
  Test.add_func ("/io/serialize_birthday",
                 Contacts.Tests.Io.test_serialize_birthday);
  Test.add_func ("/io/serialize_birthday_pre_epoch",
                 Contacts.Tests.Io.test_serialize_birthday_pre_epoch);
  Test.run ();
}

namespace Contacts.Tests.Io {

  private void test_serialize_birthday () {
    unowned var bd_key = PersonaStore.detail_key (PersonaDetail.BIRTHDAY);

    DateTime old_bd = new GLib.DateTime.utc (1992, 8, 1, 0, 0, 0);
    var old_bd_val = Value (typeof (DateTime));
    old_bd_val.set_boxed (old_bd);

    var new_bd_val = _transform_single_value (bd_key, old_bd_val);
    assert_true (new_bd_val.type () == typeof (DateTime));
    assert_true (old_bd.equal ((DateTime) new_bd_val.get_boxed ()));
  }

  private void test_serialize_birthday_pre_epoch () {
    unowned var bd_key = PersonaStore.detail_key (PersonaDetail.BIRTHDAY);

    DateTime old_bd = new GLib.DateTime.utc (1961, 7, 3, 0, 0, 0);
    var old_bd_val = Value (typeof (DateTime));
    old_bd_val.set_boxed (old_bd);

    var new_bd_val = _transform_single_value (bd_key, old_bd_val);
    assert_true (new_bd_val.type () == typeof (DateTime));
    assert_true (old_bd.equal ((DateTime) new_bd_val.get_boxed ()));
  }
}
