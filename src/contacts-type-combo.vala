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

using Gtk;
using Gee;
using Folks;

/**
 * The TypeCombo is a widget that fills itself with the types of a certain
 * category (using {@link Contacts.TypeSet}). For example, it allows the user
 * to choose between "Personal", "Home" and "Work" for email addresses,
 * together with all the custom labels it has encountered since then.
 */
public class Contacts.TypeCombo : ComboBox  {

  private unowned TypeSet type_set;

  /**
   * The {@link Contacts.TypeDescriptor} that is currently shown
   */
  public TypeDescriptor active_descriptor {
    get {
      TreeIter iter;

      get_active_iter (out iter);
      assert (!is_separator (this.model, iter));

      unowned TypeDescriptor descriptor;
      this.model.get (iter, 1, out descriptor);
      return descriptor;
    }
    set {
      set_active_iter (value.iter);
    }
  }

  construct {
    this.valign = Align.START;
    this.halign = Align.FILL;
    this.hexpand = true;
    this.visible = true;

    var renderer = new CellRendererText ();
    pack_start (renderer, true);
    set_attributes (renderer, "text", 0);

    set_row_separator_func (is_separator);
  }

  /**
   * Creates a TypeCombo for the given TypeSet. To set the active value,
   * use the "current-decsriptor" property, set_active_from_field_details(),
   * or set_active_from_vcard_type()
   */
  public TypeCombo (TypeSet type_set) {
    this.type_set = type_set;
    this.model = type_set.store;
  }

  private bool is_separator (TreeModel model, TreeIter iter) {
    unowned string? s;
    model.get (iter, 0, out s);
    return s == null;
  }

  /**
   * Sets the value to the type of the given {@link Folks.AbstractFieldDetails}.
   */
  public void set_active_from_field_details (AbstractFieldDetails details) {
    this.active_descriptor = this.type_set.lookup_descriptor_for_field_details (details);
  }

  /**
   * Sets the value to the type that best matches the given vcard type
   * (for example "HOME" or "WORK").
   */
  public void set_active_from_vcard_type (string type) {
    TreeIter iter;
    this.type_set.get_iter_for_vcard_type (type, out iter);
    set_active_iter (iter);
  }
}
