/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
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
 * The TypeComboRow is a widget that fills itself with the types of a certain
 * category (using {@link Contacts.TypeSet}). For example, it allows the user
 * to choose between "Personal", "Home" and "Work" for email addresses,
 * together with all the custom labels it has encountered since then.
 */
public class Contacts.TypeComboRow : Adw.ComboRow  {

  public TypeDescriptor selected_descriptor {
    get { return (TypeDescriptor) this.selected_item; }
  }

  public TypeSet type_set {
    get { return (TypeSet) this.model; }
  }

  /**
   * Creates a TypeComboRow for the given TypeSet.
   */
  public TypeComboRow (TypeSet type_set) {
    Object (
      model: type_set,
      expression: new Gtk.PropertyExpression (typeof (TypeDescriptor), null, "display-name")
    );
  }

  /**
   * Sets the value to the type of the given {@link Folks.AbstractFieldDetails}.
   */
  public void set_selected_from_field_details (AbstractFieldDetails details) {
    uint position = 0;
    this.type_set.lookup_by_field_details (details, out position);
    this.selected = position;
  }

  /**
   * Sets the value to the type that best matches the given vcard type
   * (for example "HOME" or "WORK").
   */
  public void set_selected_from_vcard_type (string type) {
    uint position = 0;
    this.type_set.lookup_by_vcard_type (type, out position);
    this.selected = position;
  }
}
