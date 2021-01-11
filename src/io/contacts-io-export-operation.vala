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
 * An Io.ExportOperation is an object that can deal with exporting one or more
 * contacts ({@link Folks.Individual}s) into a serialized format (VCard is the
 * most common example, but there exist also CSV based formats and others).
 *
 * Note that unlike a Io.Importer, we can skip the whole {@link GLib.HashTable}
 * dance, since we aren't dealing with untrusted data anymore.
 */
public abstract class Contacts.Io.ExportOperation : Contacts.Operation {

  /** The list of individuals that will be exported */
  public Gee.List<Individual> individuals { get; construct set; }

  /**
   * The generic output stream to export the individuals to.
   *
   * If you want to export to:
   * - a file, use the result of {@link GLib.File.create}
   * - a string, create a {@link GLib.MemoryOutputStream} and append a '\0'
   *   terminator at the end
   * - ...
   */
  public GLib.OutputStream output { get; construct set; }

  public override bool reversable { get { return false; } }

  protected override async void _undo () throws GLib.Error {
    // No need to do anything, since reversable is false
  }
}
