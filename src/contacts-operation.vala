/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@redhat.com>
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

/**
 * Contacts.Operation is a simple interface to describe actions that can be
 * executed and possibly undone later on (for example, using a button on an
 * in-app notification).
 *
 * Since some operations might not be able undoable later onwards, there is a
 * property `reversable` that you should check first before calling undo().
 */
public interface Contacts.Operation : Object {

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
