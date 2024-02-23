/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
   * terminator at the end
   * - ...
   */
  public GLib.OutputStream output { get; construct set; }

  public override bool reversable { get { return false; } }

  protected override async void _undo () throws GLib.Error {
    // No need to do anything, since reversable is false
  }
}
