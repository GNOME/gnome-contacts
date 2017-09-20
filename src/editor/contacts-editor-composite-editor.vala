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
 * An interface for DetailsEditors that contain multiple child Element.
 * It has a ChildDetails type (C), for the Details a child widget represents
 */
public abstract class Contacts.Editor.CompositeEditor<D, C> : DetailsEditor<D>  {

  protected Gee.List<CompositeEditorChild<C>> child_editors = new LinkedList<CompositeEditorChild<C>> ();

  public override int attach_to_grid (Grid container_grid, int start_row) {
    var current_row = start_row;
    foreach (var child_editor in this.child_editors)
      current_row += child_editor.attach_to_grid (container_grid, current_row);

    return current_row - start_row;
  }

  public override Value create_value () {
    var children = aggregate_children ();
    var val = Value (children.get_type ());
    val.set_object (children);
    return val;
  }

  protected HashSet<C> aggregate_children () {
    var children = new HashSet<C> ();
    foreach (var child_editor in this.child_editors)
      children.add (child_editor.create_details ());
    return children;
  }
}

/**
 * A child to a CompositeEditor.
 */
public abstract class Contacts.Editor.CompositeEditorChild<D> : Object {

  protected MultiMap<string, string> parameters;

  /**
   * Creates the details for this CompositeEditorChild, based on the (edited) values.
   */
  public abstract D create_details ();

  public abstract int attach_to_grid (Grid container_grid, int start_row);
}
