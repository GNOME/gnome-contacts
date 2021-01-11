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
  Test.add_func ("/io/serialize_structured_name_simple",
                 Contacts.Tests.Io.test_serialize_structured_name_simple);
  Test.run ();
}

namespace Contacts.Tests.Io {

  private void test_serialize_structured_name_simple () {
    unowned var sn_key = PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME);

    var old_sn = new StructuredName.simple ("Niels", "De Graef");
    Value old_sn_val = Value (typeof (StructuredName));
    old_sn_val.set_object (old_sn);

    var new_sn_val = _transform_single_value (sn_key, old_sn_val);

    if (new_sn_val.type () != typeof (StructuredName))
      error ("Expected FOLKS_TYPE_STRUCTURED_NAME but got %s", new_sn_val.type ().name ());

    var new_sn = new_sn_val.get_object () as StructuredName;
    if (!old_sn.equal (new_sn))
      error ("Expected '%s' but got '%s'", old_sn.to_string (), new_sn.to_string ());
  }
}
