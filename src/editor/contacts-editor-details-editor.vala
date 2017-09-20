/*
 * Copyright (C) 2017 Niels De Graef <nielsdegraef@gmail.com>
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
using Gee;
using Gtk;

/**
 * A DetailsEditor is an Element that can handle a specific property of a Persona.
 */
public abstract class Contacts.Editor.DetailsEditor<D> : Object {

  /**
   * Fired when the user asks to remove the EditorElement.
   */
  public signal void removed ();

  /**
   * Returns whether the DetailsEditor has unsaved changes.
   */
  public bool dirty { get; protected set; default = false; }

  /**
   * Returns the Persona property (well, the string) this EditorElement takes care of.
   */
  public abstract string persona_property { get; }

  /**
   * Attaches the element to the grid (possibly over multiple rows).
   *
   * @param container_grid The grid to which the element should be added.
   * @param start_row The row at which we should start editing.
   *
   * @return The amount of rows that were added to the grid by this EditorElement.
   */
  public abstract int attach_to_grid (Grid container_grid, int start_row);

  /**
   * Saves the (edited) value to the Details object.
   */
  public abstract async void save (D details) throws PropertyError;

  public async void save_to_persona (Persona persona) throws PropertyError {
    yield save ((D) persona);
  }

  /**
   * Returns a Value that can be used for methods like Folks.PersonaStore.add_persona_from_details()
   */
  public abstract Value create_value ();

  /* Helper methods for building
   ----------------------------- */
  public TypeCombo create_type_combo (TypeSet type_set, AbstractFieldDetails? details = null) {
    var combo = new TypeCombo (type_set);
    combo.hexpand = false;
    if (details != null)
      combo.set_active (details);
    combo.valign = Align.CENTER; // XXX why not START?
    combo.changed.connect (() => { this.dirty = true; });
    combo.show ();

    return combo;
  }

  public Label create_label (string text) {
    var label = new Label (text);
    label.hexpand = false;
    label.valign = Align.START;
    label.halign = Align.END;
    label.margin_end = 6;
    label.get_style_context ().add_class ("dim-label");
    label.show ();

    return label;
  }

  public Entry create_entry (string? text, string? placeholder = null) {
    var entry = new Entry ();
    entry.hexpand = true;
    if (text != null)
      entry.text = text;
    if (placeholder != null)
      entry.placeholder_text = placeholder;
    entry.show ();

    entry.changed.connect (() => { this.dirty = true; });

    return entry;
  }

  // XXX scrolledwindow?
  public ScrolledWindow create_textview (string? text = null) {
    var sw = new ScrolledWindow (null, null);
    sw.shadow_type = ShadowType.OUT;
    sw.set_size_request (-1, 100);

    var value_text = new TextView ();
    if (text != null)
      value_text.get_buffer ().set_text (text);
    value_text.hexpand = true;

    sw.add (value_text);
    sw.show_all ();

    value_text.get_buffer ().changed.connect (() => { this.dirty = true; });

    /* return value_text; */
    return sw;
  }

  public Button create_delete_button () {
    var delete_button = new Button.from_icon_name ("edit-delete-symbolic");
    delete_button.valign = Align.START;
    delete_button.get_accessible ().set_name (_("Delete field"));
    delete_button.get_style_context ().add_class ("flat");
    delete_button.clicked.connect (() => removed ());
    delete_button.show ();

    return delete_button;
  }
}
