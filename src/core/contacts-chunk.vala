/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
   * The user-visible name for this property
   */
  public abstract string display_name { get; }

  /**
   * The name of an icon to show to the user, if any
   */
  public abstract string? icon_name { get; }

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
  public abstract async void save_to_persona () throws GLib.Error;

  /**
   * Serializes this chunk into a {@link GLib.Variant} accordding to an
   * internal format (which can be deserialized later using apply_gvariant())
   *
   * If the field is empty or non-existent, it should return null.
   */
  public abstract Variant? to_gvariant ();

  /**
   * Takes the given variant describing this chunk (in other words, the result
   * of to_gvariant() and copies the values accordingly.
   *
   * If the variant represents the *original* value for this chunk (as there's
   * no appropriate construct property), then you can set mark_dirty to false.
   */
  public abstract void apply_gvariant (Variant variant,
                                       bool mark_dirty = true);
}
