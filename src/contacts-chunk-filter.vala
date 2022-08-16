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
 * A custom GtkFilter to filter {@link Chunk}s for a consistent way of
 * displaying them.
 */
public class Contacts.ChunkFilter : Gtk.Filter {

  public ChunkPropertyFilter? property_filter { get; set; default = null; }

  /** Whether empty chunks match the filter */
  public bool allow_empty {
    get { return this.empty_filter.allow_empty; }
    set { this.empty_filter.allow_empty = value; }
  }
  private ChunkEmptyFilter empty_filter = new ChunkEmptyFilter ();

  /** A subfilter that can be used to match the persona of each chunk */
  public PersonaFilter? persona_filter { get; set; default = null; }

  /**
   * Creates a ChunkFilter for a specific property
   */
  public ChunkFilter.for_property (string property_name, bool allow_empty = false) {
    Object (property_filter: new ChunkPropertyFilter.for_single (property_name),
            allow_empty: allow_empty);
  }

  public override bool match (GLib.Object? item) {
    unowned var chunk = (Chunk) item;

    return match_property_name (chunk)
        && this.empty_filter.match (chunk)
        && match_persona (chunk);
  }

  private bool match_property_name (Chunk chunk) {
    return this.property_filter == null || this.property_filter.match (chunk);
  }

  private bool match_persona (Chunk chunk) {
    if (this.persona_filter == null)
      return true;

    return chunk.persona == null || this.persona_filter.match (chunk.persona);
  }

  public override Gtk.FilterMatch get_strictness () {
    return Gtk.FilterMatch.SOME;
  }
}
