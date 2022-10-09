/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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
 * A "chunk" is a piece of data that describes a specific property of a
 * {@link Contact}. Each chunk usually maps to a specific vCard property, or an
 * interface related to a property of a {@link Folks.Persona}.
 */
public abstract class Contacts.Chunk : GLib.Object {

  /** The associated persona (or null if we're creating a new one) */
  public Persona? persona { get; construct set; default = null; }

  /**
   * The specific property of this chunk.
   *
   * Note that this should match with the string representation of a
   * {@link Folks.PersonaDetail}.
   */
  public abstract string property_name { get; }

  /**
   * Whether this is empty. As an example, you can use to changes in this
   * property to update any UI.
   */
  public abstract bool is_empty { get; }

  /**
   * A separate field to keep track of whether this has changed from its
   * original value. If it did, we know we'll have to (possibly) save the
   * changes.
   */
  public abstract bool dirty { get; }

  /**
   * Converts this chunk into a GLib.Value, as expected by API like
   * {@link Folks.PersonaStore.add_persona_from_details}
   *
   * If the field is empty or non-existent, it should return null.
   */
  public abstract Value? to_value ();

  /**
   * Calls the appropriate API to save to the persona.
   */
  public abstract async void save_to_persona () throws GLib.Error
      requires (this.persona != null);
}
