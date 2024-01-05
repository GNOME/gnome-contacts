/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

/**
 * Contacts.Operation is a simple interface to describe actions that can be
 * executed and possibly undone later on (for example, using a button on an
 * in-app notification).
 *
 * Since some operations might not be able undoable later onwards, there is a
 * property `reversable` that you should check first before calling undo().
 *
 * Note that you probably shouldn't be calling the execute() method directly,
 * but use the API provided by {@link OperationQueue} instead.
 */
public abstract class Contacts.Operation : Object {

  /** The UUID of the operation */
  public string uuid { get; private set; default = Uuid.string_random (); }

  /**
   * Whether undo() can be called on this object
   */
  public abstract bool reversable { get; }

  /**
   * A user-facing string that tells us what the operation does
   */
  public abstract string description { owned get; }

  /**
   * This the actual implementation of the operation that a subclass needs to
   * implement.
   */
  public abstract async void execute () throws GLib.Error;

  /**
   * The is the public API undo. If you want, you can override it still, e.g.
   * to provide better warnings.
   */
  public virtual async void undo () throws GLib.Error {
    // FIXME: should throw an error instead so we can show something to the user
    if (!this.reversable) {
      warning ("Can't undo '%s'", this.description);
      return;
    }

    yield this._undo ();
  }

  /**
   * This the actual implementation of the undo that a subclass needs to
   * implement.
   */
  protected abstract async void _undo () throws GLib.Error;
}
