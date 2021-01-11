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
  Test.add_func ("/io/serialize_full_name_simple",
                 Contacts.Tests.Io.test_serialize_full_name_simple);
  Test.run ();
}

namespace Contacts.Tests.Io {

  private void test_serialize_full_name_simple () {
    unowned var fn_key = PersonaStore.detail_key (PersonaDetail.FULL_NAME);

    string old_fn = "Niels De Graef";
    Value old_fn_val = Value (typeof (string));
    old_fn_val.set_string (old_fn);

    var new_fn_val = _transform_single_value (fn_key, old_fn_val);
    if (new_fn_val.type () != typeof (string))
      error ("Expected G_TYPE_STRING but got %s", new_fn_val.type ().name ());
    if (old_fn != new_fn_val.get_string ())
      error ("Expected '%s' but got '%s'", old_fn, new_fn_val.get_string ());
  }
}
