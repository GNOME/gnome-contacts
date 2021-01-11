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
 * Launches a subprocess to deal with the import of a Contact file
 */
public class Contacts.ImportOperation {

    private File input_file;

    public ImportOperation (File file) {
      this.input_file = file;
    }

    public async void execute () throws Error {
      var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE);
      // Make sure we're not accidentally propagating the G_MESSAGES_DEBUG variable
      launcher.set_environ ({});

      debug ("Spawning import subprocess");
      var subprocess = launcher.spawnv ({
          "/home/niels/jhbuild/install/libexec/gnome-contacts/gnome-contacts-import",
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

      unowned var serialized_str = (string) stdout_stream.get_data ();

      try {
        var variant = Variant.parse (VariantType.VARDICT, serialized_str);

        var new_details = Contacts.Io.deserialize_gvariant (variant);
        if (new_details.size () == 0) {
          warning ("Imported contact has zero fields");
          return;
        }

        // TODO now what? :p

      } catch (VariantParseError err) {
        Variant.parse_error_print_context (err, serialized_str);
      }

      // TODO bytes or string?
      // var variant = Variant.new_from_data<void> (VariantType.VARDICT, stdout_stream.get_data (), false);

    }
}
