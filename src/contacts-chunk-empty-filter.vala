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
 * A custom GtkFilter to filter {@link Chunk}s on them possibly being non-empty.
 */
public class Contacts.ChunkEmptyFilter : Gtk.Filter {

  /** Whether empty chunks match the filter */
  public bool allow_empty {
    get { return this._allow_empty; }
    set {
      if (this._allow_empty == value)
        return;

      this._allow_empty = value;
      changed (value? Gtk.FilterChange.LESS_STRICT : Gtk.FilterChange.MORE_STRICT);
    }
  }
  private bool _allow_empty = false;

  public override bool match (GLib.Object? item) {
    unowned var chunk = (Chunk) item;
    return match_empty (chunk);
  }

  private bool match_empty (Chunk chunk) {
    return this.allow_empty || !chunk.is_empty;
  }

  public override Gtk.FilterMatch get_strictness () {
    return this.allow_empty? Gtk.FilterMatch.ALL : Gtk.FilterMatch.SOME;
  }
}
