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

  // if this.query is a SimpleQuery, we can save the query string to enable
  // some optimizations (see later)
  private string query_string = "";

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

  construct {
    if (this.query is SimpleQuery)
      this.query_string = ((SimpleQuery) this.query).query_string;
    this.query.notify.connect (on_query_notify);
  }

  public QueryFilter (Query query) {
    Object (query: query);
  }

  private void on_query_notify (Object object, ParamSpec pspec) {
    unowned var query = (Query) object;

    // We can optimize a bit in the case of a SimpleQuery
    if (query is SimpleQuery) {
      // SimpleQuery notifies its locale changed on a query string update,
      // even if it didn't change (and we don't support changing it either)
      if (pspec.get_name () == "query-locale")
        return;

      // A very common use case is that the user is typing in the search bar.
      // In case they add a letter, we know the filter will be more strict (and
      // vice versa)
      if (pspec.get_name () == "query-string") {
        var old_query_str = this.query_string;
        this.query_string = ((SimpleQuery) query).query_string;

        // We shouldn't get a notify for this but in reality we do, so ignore it
        if (this.query_string == old_query_str)
          return;

        if (this.query_string.length > old_query_str.length &&
            this.query_string.index_of (old_query_str) != -1) {
          this.changed (Gtk.FilterChange.MORE_STRICT);
          return;
        }
        if (this.query_string.length < old_query_str.length &&
            old_query_str.index_of (this.query_string) != -1) {
          this.changed (Gtk.FilterChange.LESS_STRICT);
          return;
        }
      }
    }

    this.changed (Gtk.FilterChange.DIFFERENT);
  }

  public override bool match (GLib.Object? item) {
    unowned var individual = item as Individual;
    return_val_if_fail (individual != null, false);

    return this.query.is_match (individual) > this.min_strength;
  }

  public override Gtk.FilterMatch get_strictness () {
    if (this.query is SimpleQuery &&
        ((SimpleQuery) query).query_string == "")
      return Gtk.FilterMatch.ALL;

    return Gtk.FilterMatch.SOME;
  }
}
