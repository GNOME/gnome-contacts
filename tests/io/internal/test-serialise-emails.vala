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
  Test.add_func ("/io/serialize_emails",
                 Contacts.Tests.Io.test_serialize_emails);
  Test.run ();
}

namespace Contacts.Tests.Io {

  private void test_serialize_emails () {
    unowned var emails_key = PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES);

    var old_fd = new EmailFieldDetails ("nielsdegraef@gmail.com");
    var new_fd = _transform_single_afd<EmailFieldDetails> (emails_key, old_fd);

    if (!(new_fd is EmailFieldDetails))
      error ("Expected EmailFieldDetails but got %s", new_fd.get_type ().name ());

    if (old_fd.value != new_fd.value)
      error ("Expected '%s' but got '%s'", old_fd.value, new_fd.value);
  }
}
