/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
      }
    }

    this.changed (Gtk.FilterChange.DIFFERENT);
  }

  public override bool match (GLib.Object? item)
      requires (item is Individual) {

    unowned var individual = item as Individual;
    return this.query.is_match (individual) > this.min_strength;
  }

  public override Gtk.FilterMatch get_strictness () {
    if (this.query is SimpleQuery &&
        ((SimpleQuery) query).query_string == "")
      return Gtk.FilterMatch.ALL;

    return Gtk.FilterMatch.SOME;
  }
}
