/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
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
 * A subclass of {@link Gtk.Filter} which applies a {@link Folks.Query} as a
 * filter on a list of individuals.
 *
 * Since {@link Folks.Query.is_match} returns a "match strength" number, you
 * can specify also an (exclusive) lower bound before the filter returns true.
 */
public class Contacts.QueryFilter : Gtk.Filter {

  public Query query { get; construct; }

  private uint _min_strength = 0;
  public uint min_strength {
    get { return this._min_strength; }
    set {
      if (value == this._min_strength)
        return;

      this._min_strength = value;
      this.changed (Gtk.FilterChange.DIFFERENT);
    }
  }

  public QueryFilter (Query query) {
    Object (query: query);

    query.notify.connect (on_query_notify);
  }

  private void on_query_notify (Object object, ParamSpec pspec) {
    this.changed (Gtk.FilterChange.DIFFERENT);
  }

  public override bool match (GLib.Object? item) {
    unowned var individual = item as Individual;
    if (individual == null)
      return false;

    return this.query.is_match (individual) > this.min_strength;
  }

  public override Gtk.FilterMatch get_strictness () {
    return Gtk.FilterMatch.SOME;
  }
}
