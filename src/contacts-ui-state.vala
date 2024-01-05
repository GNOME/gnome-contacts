/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
   * A single contact is selected and displayed.
   */
  SHOWING,

  /**
   * Zero or more contacts are selected (but this can be changed).
   * One contact might be displayed.
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
