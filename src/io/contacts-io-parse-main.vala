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

int main (string[] args) {
  if (args.length != 3)
    error ("Expected exactly 2 arguments, but got %d", args.length - 1);

  unowned var import_type = args[1];
  if (import_type == "")
    error ("Invalid import type: got empty import type");

  unowned var path = args[2];
  if (path == "")
    error ("Invalid path: path is empty");

  Contacts.Io.Parser parser;
  switch (import_type) {
    case "vcard":
      parser = new Contacts.Io.VCardParser ();
      break;
    default:
      error ("Unknown import type '%s'", import_type);
  }

  HashTable<string, Value?>[] details_list;
  try {
    var file = File.new_for_path (path);
    var file_stream = file.read (null);
    details_list = parser.parse (file_stream);
  } catch (Error err) {
    error ("Error while importing file '%s': %s", path, err.message);
  }

  // Serialize
  var serialized = Contacts.Io.serialize_to_gvariant (details_list);

  // TODO: Switch to raw bytes (performance). Use variant.print/parse while we're ironing out bugs
#if 0
  var bytes = serialized.get_data_as_bytes ();
  stdout.write (bytes.get_data (), bytes.get_size ());
#endif
  stdout.write (serialized.print (false).data);

  return 0;
}
