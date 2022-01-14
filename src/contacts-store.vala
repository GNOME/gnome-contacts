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
 * The Contacts.Store is the base abstraction that holds all contacts (i.e.
 * {@link Folks.Indidivual}s). Note that it also has a "quiescent" and
 * "prepared" signal, with similar effects to those of a
 * {@link Folks.IndividualAggregator}.
 *
 * Internally, the Store works with 3 list models layered on top of each other:
 *
 * - A base list model which contains all contacts in the
 *   {@link Folks.IndividualAggregator}
 * - A {@link Gtk.SortListModel}, which sorts the base model according to
 *   first name or last name, or whatever user preference
 * - A {@link Gtk.FilterListModel} to filter out contacts using a
 *   {@link Folks.Query}, so a user can filter contacts with the search entry
 */
public class Contacts.Store : GLib.Object {

  public signal void quiescent ();
  public signal void prepared ();

  public IndividualAggregator aggregator { get; private set; }
  public BackendStore backend_store { get { return this.aggregator.backend_store; } }

  // Base list model
  private GLib.ListStore _base_model = new ListStore (typeof (Individual));
  public GLib.ListModel base_model { get { return this._base_model; } }

  // Sorting list model
  public Gtk.SortListModel sort_model { get; private set; }
  public IndividualSorter sorter { get; private set; }

  // Filtering list model
  public Gtk.FilterListModel filter_model { get; private set; }
  public QueryFilter filter { get; private set; }

  // Selection list model
  public Gtk.SingleSelection selection { get; private set; }

  public Gee.HashMultiMap<string, string> dont_suggest_link;

#if HAVE_TELEPATHY
  public TelepathyGLib.Account? caller_account { get; private set; default = null; }
#endif

  private void read_dont_suggest_db () {
    dont_suggest_link.clear ();

    var path = Path.build_filename (Environment.get_user_config_dir (), "gnome-contacts", "dont_suggest.db");
    try {
      string contents;
      FileUtils.get_contents (path, out contents);

      var rows = contents.split ("\n");
      foreach (unowned string r in rows) {
        var ids = r.split (" ");
        if (ids.length == 2) {
          dont_suggest_link.set (ids[0], ids[1]);
        }
      }
    } catch (GLib.Error e) {
      if (e is FileError.NOENT)
        return;

      warning ("error loading no suggestion db: %s\n", e.message);
    }
  }

  private void write_dont_suggest_db () {
    try {
      var dir = Path.build_filename (Environment.get_user_config_dir (), "gnome-contacts");
      DirUtils.create_with_parents (dir, 0700);
      var path = Path.build_filename (dir, "dont_suggest.db");

      var s = new StringBuilder ();
      foreach (var key in dont_suggest_link.get_keys ()) {
        foreach (var value in dont_suggest_link.get (key))
          s.append_printf ("%s %s\n", key, value);
      }
      FileUtils.set_contents (path, s.str, s.len);
    } catch (GLib.Error e) {
      warning ("error writing no suggestion db: %s\n", e.message);
    }
  }

  public bool may_suggest_link (Individual a, Individual b) {
    foreach (var a_persona in a.personas) {
      foreach (var no_link_uid in dont_suggest_link.get (a_persona.uid)) {
        foreach (var b_persona in b.personas) {
          if (b_persona.uid == no_link_uid)
            return false;
        }
      }
    }
    foreach (var b_persona in b.personas) {
      foreach (var no_link_uid in dont_suggest_link.get (b_persona.uid)) {
        foreach (var a_persona in a.personas) {
          if (a_persona.uid == no_link_uid)
            return false;
        }
      }
    }
    return true;
  }

  public void add_no_suggest_link (Individual a, Individual b) {
    var persona1 = a.personas.to_array ()[0];
    var persona2 = b.personas.to_array ()[0];
    dont_suggest_link.set (persona1.uid, persona2.uid);
    write_dont_suggest_db ();
  }

  construct {
    this.dont_suggest_link = new Gee.HashMultiMap<string, string> ();
    read_dont_suggest_db ();

    var backend_store = BackendStore.dup ();

    this.aggregator = IndividualAggregator.dup_with_backend_store (backend_store);
    aggregator.notify["is-quiescent"].connect ((obj, pspec) => {
      // We seem to get this before individuals_changed, so hack around it
      Idle.add( () => {
        this.quiescent ();
        return false;
      });
    });

    aggregator.notify["is-prepared"].connect ((obj, pspec) => {
      Idle.add( () => {
        this.prepared ();
        return false;
      });
    });

    this.aggregator.individuals_changed_detailed.connect (on_individuals_changed_detailed);
    aggregator.prepare.begin ();

#if HAVE_TELEPATHY
    check_call_capabilities.begin ();
#endif
  }

  public Store (GLib.Settings settings, Folks.Query query) {
    // Create the sorting, filtering and selection models
    this.sorter = new IndividualSorter (settings);
    this.sort_model = new Gtk.SortListModel (this.base_model, this.sorter);

    this.filter = new QueryFilter (query);
    this.filter_model = new Gtk.FilterListModel (this.sort_model, this.filter);

    this.selection = new Gtk.SingleSelection (this.filter_model);
    this.selection.autoselect = false;
  }

  private void on_individuals_changed_detailed (Gee.MultiMap<Individual?,Individual?> changes) {
    var to_add = new GenericArray<unowned Individual> ();
    var to_remove = new GenericArray<unowned Individual> ();

    foreach (var individual in changes.get_keys ()) {
      if (individual != null)
        to_remove.add (individual);
      foreach (var new_i in changes[individual]) {
        if (new_i != null)
          to_add.add (new_i);
      }
    }

    debug ("Individuals changed: %d added, %d removed", to_add.length, to_remove.length);

    // Remove old individuals. It's not the most performance way of doing it,
    // but optimizing for it (and making it more comples) makes little sense.
    foreach (unowned var indiv in to_remove) {
      uint pos = 0;
      if (this._base_model.find (indiv, out pos)) {
        this._base_model.remove (pos);
      } else {
        debug ("Tried to remove individual '%s', but could't find it", indiv.display_name);
      }
    }

    // Add new individuals
    foreach (unowned var indiv in to_add) {
      if (indiv.personas.size == 0 || Utils.is_ignorable (indiv)) {
        to_add.remove_fast (indiv);
      } else {
        // We want to make sure that changes in the Individual triggers changes
        // in the list model if it affects sorting and/or filtering. Atm, the
        // only thing that can lead to this is a change in display name or
        // whether they are marked as favourite.
        indiv.notify.connect ((obj, pspec) => {
          unowned var prop_name = pspec.get_name ();
          if (prop_name != "display-name" && prop_name != "is-favourite")
            return;

          uint pos;
          if (this._base_model.find (obj, out pos)) {
            this._base_model.items_changed (pos, 1, 1);
          }
        });
      }
    }
    this._base_model.splice (this.base_model.get_n_items (), 0, (Object[]) to_add.data);
  }

  public unowned Individual? get_selected_contact () {
    return (Individual) this.selection.get_selected_item ();
  }

  /**
   * A helper method to find a contact based on the given search query, while
   * making sure to take care of (wait for) the "quiescent" property of the
   * IndividualAggregator.
   */
  public async uint find_individual_for_query (Query query) {
    // Wait that the store gets quiescent if it isn't already
    if (!this.aggregator.is_quiescent) {
      ulong signal_id;
      SourceFunc callback = find_individual_for_query.callback;
      signal_id = this.quiescent.connect (() => {
        callback ();
      });
      yield;
      disconnect (signal_id);
    }

    // We search for the closest matching Individual
    uint matched_pos = Gtk.INVALID_LIST_POSITION;
    uint strength = 0;
    for (uint i = 0; i < this.filter_model.get_n_items (); i++) {
      var individual = (Individual) this.filter_model.get_item (i);
      uint this_strength = query.is_match (individual);
      if (this_strength > strength) {
        matched_pos = i;
        strength = this_strength;
      }
    }

    return matched_pos;
  }

  /**
   * A helper method to find a contact based on the given individual id, while
   * making sure to take care of (wait for) the "quiescent" property of the
   * IndividualAggregator.
   */
  public async uint find_individual_for_id (string id) {
    // Wait that the store gets quiescent if it isn't already
    if (!this.aggregator.is_quiescent) {
      ulong signal_id;
      SourceFunc callback = find_individual_for_id.callback;
      signal_id = this.quiescent.connect (() => {
        callback ();
      });
      yield;
      disconnect (signal_id);
    }

    for (uint i = 0; i < this.filter_model.get_n_items (); i++) {
      var individual = (Individual) this.filter_model.get_item (i);
      if (individual.id == id)
        return i;
    }

    return Gtk.INVALID_LIST_POSITION;
  }

#if HAVE_TELEPATHY
  // TODO: listen for changes in Account#URISchemes
  private async void check_call_capabilities () {
    var account_manager = TelepathyGLib.AccountManager.dup ();

    try {
      yield account_manager.prepare_async (null);

      account_manager.account_enabled.connect (check_account_caps);
      account_manager.account_disabled.connect (check_account_caps);

      foreach (var account in account_manager.dup_valid_accounts ())
        yield check_account_caps (account);
    } catch (GLib.Error e) {
      warning ("Unable to check accounts caps %s", e.message);
    }
  }

  private async void check_account_caps (TelepathyGLib.Account account) {
    GLib.Quark addressing = TelepathyGLib.Account.get_feature_quark_addressing ();
    if (!account.is_prepared (addressing)) {
      GLib.Quark[] features = { addressing };
      try {
        yield account.prepare_async (features);
      } catch (GLib.Error e) {
        warning ("Unable to prepare account %s", e.message);
      }
    }

    if (account.is_prepared (addressing)) {
      if (account.is_enabled () && account.associated_with_uri_scheme ("tel"))
        this.caller_account = account;
    }
  }
#endif
}
