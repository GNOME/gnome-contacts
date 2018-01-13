/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
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
 * Roughly put, the behaviour of the UI of Contacts can be divided in several
 * categories. We represent this with the UiState enum, which can be shared
 * (and sync-ed) between the different parts of the app.
 *
 * Note that there is one exception to this: the initial setup is handled
 * completely separately in the {@link SetupWindow}.
 */
public enum Contacts.UiState {
  /**
   * The start state: no contact is selected/displayed.
   */
  NORMAL,

  /**
   * A contact has been selected and is displayed.
   */
  SHOWING,

  /**
   * Zero or more contacts are selected (but this can be changed).
   * No contact should be displayed.
   */
  SELECTING,

  /**
   * The selected contact is being edited.
   */
  UPDATING,

  /**
   * A new contact is being created.
   */
  CREATING;

  /**
   * Returns whether we're editing a contact, either by changing an existing
   * one, or by creating a new one.
   */
  public bool editing () {
    return this == UiState.UPDATING || this == UiState.CREATING;
  }
}
