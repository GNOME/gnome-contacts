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
  Test.add_func ("/io/test_vcard_minimal",
                 Contacts.Tests.Io.test_vcard_minimal);
  Test.run ();
}

namespace Contacts.Tests.Io {
  private void test_vcard_minimal () {
    unowned var vcf_path = Environment.get_variable ("_VCF_FILE");
    if (vcf_path == null || vcf_path == "")
      error ("No .vcf file set as envvar. Please use the meson test suite");

    var file = GLib.File.new_for_path (vcf_path);
    if (!file.query_exists ())
      error (".vcf file that is used as test input doesn't exist");

    var parser = new Contacts.Io.VCardParser ();
    HashTable<string, Value?>[] details_list = null;
    try {
      details_list = parser.parse (file.read (null));
    } catch (Error err) {
      error ("Error while importing: %s", err.message);
    }
    if (details_list == null)
      error ("VCardParser returned null");

    if (details_list.length != 1)
      error ("VCardParser parsed %u elements instead of 1", details_list.length);

    unowned var details = details_list[0];

    unowned var fn_key = PersonaStore.detail_key (PersonaDetail.FULL_NAME);
    if (!details.contains (fn_key))
      error ("No FN value");

    var fn_value = details.lookup (fn_key);
    unowned var fn = fn_value as string;
    if (fn != "Niels De Graef")
      error ("Expected '%s' but got '%s'", "Niels De Graef", fn);
  }
}
