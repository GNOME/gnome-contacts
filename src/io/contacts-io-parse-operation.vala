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

/**
 * A ParseOperation launches a subprocess which asynchronously
 * parses the given input into a set of {@link GLib.HashTable}s,
 * which can then be imported using a
 * {@link Contacts.Io.ImportOperation}
 */
public class Contacts.Io.ParseOperation : Operation {

  private File input_file;

  public override bool reversable { get { return false; } }

  private string _description;
  public override string description { owned get { return this._description; } }

  /** The parsed output  */
  private GenericArray<Contact> parsed = new GenericArray<Contact> ();

  public ParseOperation (File file) {
    this._description = _("Importing contacts from '%s'").printf (file.get_uri ());

    this.input_file = file;
  }

  public override async void execute () throws GLib.Error {
    var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE);
    // Make sure we're not accidentally propagating the G_MESSAGES_DEBUG variable
    launcher.set_environ ({});

    debug ("Spawning parse subprocess");
    var subprocess = launcher.spawnv ({
        Config.LIBEXECDIR + "/gnome-contacts/gnome-contacts-parser",
        "vcard",
        this.input_file.get_path ()
    });

    // Hook up stdout to a MemoryOutputStream, so we can easily fetch the output
    var proc_stdout = subprocess.get_stdout_pipe ();
    var stdout_stream = new MemoryOutputStream.resizable ();
    try {
      yield stdout_stream.splice_async (proc_stdout, 0, Priority.DEFAULT, null);
    } catch (Error err) {
      warning ("Error fetching stdout of import subprocess: %s", err.message);
      return;
    }

    debug ("Waiting for import subprocess to finish");
    var success = yield subprocess.wait_check_async ();
    debug ("Import subprocess finished");
    if (!success) {
      warning ("Import process exited with error status %d", subprocess.get_exit_status ());
      return;
    }

    // Ensure we have a proper string by adding a NULL terminator
    stdout_stream.write ("\0".data);
    stdout_stream.close ();

    // Parse into a GLib.Variant
    unowned var serialized_str = (string) stdout_stream.get_data ();
    var variant = Variant.parse (new VariantType ("aa{sv}"), serialized_str);

    // Now parse each into a Contact
    var parsed_contacts = Contacts.Io.deserialize_gvariant (variant);
    foreach (unowned var parsed_contact in parsed_contacts) {
      if (parsed_contact.get_n_items () == 0) {
        warning ("Imported contact has zero fields, ignoring");
        return;
      }

      this.parsed.add (parsed_contact);
    }
  }

  public override async void _undo () throws GLib.Error {
    return_if_reached ();
  }

  public unowned Contact[] get_parsed_result () {
    return this.parsed.data;
  }

  public Contact[] steal_parsed_result () {
    return this.parsed.steal ();
  }
}
