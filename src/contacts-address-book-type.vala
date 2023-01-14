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

public enum Contacts.AddressBookType {
  LOCAL,
  CARDDAV,
  LDAP;

  /**
   * Returns a user-facing string representation of the type
   */
  public unowned string to_string () {
    switch (this) {
      case LOCAL:
        return _("Local");
      case CARDDAV:
        return _("CardDAV");
      case LDAP:
        return _("LDAP");
    }
    return_val_if_reached (null);
  }

  /**
   * Returns the string as expected by E.SourceBackend.set_name()
   */
  public unowned string to_e_backend_name () {
    switch (this) {
      case LOCAL:
        return "local";
      case CARDDAV:
        return "carddav";
      case LDAP:
        return "ldap";
    }
    return_val_if_reached (null);
  }
}
