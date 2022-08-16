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

using Folks;

/**
 * A custom GtkFilter to filter {@link Chunk}s on a given property.
 */
public class Contacts.ChunkPropertyFilter : Gtk.Filter {

  /** If not empty, only the properties in the string list will match */
  public Gtk.StringList allowed_properties {
    get { return this._allowed_properties; }
    construct set {
      this._allowed_properties = value;
      value.items_changed.connect ((list, pos, removed, added) => {
        if ((added > 0 && removed == 0) || list.get_n_items () == 0)
          changed (Gtk.FilterChange.LESS_STRICT);
        else if (added == 0 && removed > 0)
          changed (Gtk.FilterChange.MORE_STRICT);
        else
          changed (Gtk.FilterChange.DIFFERENT);
      });
    }
  }
  private Gtk.StringList _allowed_properties = null;

  /**
   * Creates a ChunkPropertyFilter for a specific property
   */
  public ChunkPropertyFilter (string[] properties) {
    Object (allowed_properties: new Gtk.StringList (properties));
  }

  /**
   * Creates a ChunkPropertyFilter for a specific property
   */
  public ChunkPropertyFilter.for_single (string property_name) {
    Object (allowed_properties: new Gtk.StringList ({ property_name }));
  }

  public override bool match (GLib.Object? item) {
    unowned var chunk = (Chunk) item;
    return match_property_name (chunk);
  }

  private bool match_property_name (Chunk chunk) {
    if (this.allowed_properties.get_n_items () == 0)
      return true;

    for (uint i = 0; i < this.allowed_properties.get_n_items (); i++) {
      if (chunk.property_name == this.allowed_properties.get_string (i))
        return true;
    }
    return false;
  }

  public override Gtk.FilterMatch get_strictness () {
    if (this.allowed_properties.get_n_items () == 0)
      return Gtk.FilterMatch.ALL;
    return Gtk.FilterMatch.SOME;
  }
}
