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
 * An Parser is an object that can deal with importing a specific format
 * of describing a Contact (VCard is the most common example, but there exist
 * also CSV based formats and others).
 *
 * The main purpose of an Io.Parser is to parser whatever input it gets into a
 * {@link GLib.HashTable} with string keys and {@link Value} as values. After
 * that, we can choose to either serialize (using the serializing methods in
 * Contacts.Io), or to immediately import it in folks using
 * {@link Folks.PersonaStore.add_from_details}.
 */
public abstract class Contacts.Io.Parser : Object {

  /**
   * Takes the given input stream and tries to parse it into a
   * {@link GLib.HashTable}, which can then be used for methods like
   * {@link Folks.PersonaStore.add_persona_from_details}.
   */
  public abstract GLib.HashTable<string, Value?>[] parse (InputStream input) throws GLib.Error;
}
