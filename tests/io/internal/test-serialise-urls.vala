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
  Test.add_func ("/io/serialize_urls_single",
                 Contacts.Tests.Io.test_serialize_urls_single);
  Test.run ();
}

namespace Contacts.Tests.Io {

  private void test_serialize_urls_single () {
    unowned var urls_key = PersonaStore.detail_key (PersonaDetail.URLS);

    var old_fd = new UrlFieldDetails ("http://www.islinuxaboutchoice.com/");
    var new_fd = _transform_single_afd<UrlFieldDetails> (urls_key, old_fd);

    if (!(new_fd is UrlFieldDetails))
      error ("Expected UrlFieldDetails but got %s", new_fd.get_type ().name ());

    if (old_fd.value != new_fd.value)
      error ("Expected '%s' but got '%s'", old_fd.value, new_fd.value);
  }
}
