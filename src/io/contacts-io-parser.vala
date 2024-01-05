/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A Parser is an object that can deal with importing a specific format of
 * describing a Contact (vCard is the most common example, but there exist
 * also CSV based formats and others).
 *
 * The main purpose of an Io.Parser is to parser whatever input it gets into an
 * array of {@link Contacts.Contact}s. After that, we can for example either
 * serialize the contact into a contact again.
 */
public abstract class Contacts.Io.Parser : Object {

  /**
   * Takes the given input stream and tries to parse it into a set of contacts.
   */
  public abstract Contact[] parse (InputStream input) throws GLib.Error;
}
