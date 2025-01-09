/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
 * {@link Folks.IndividualAggregator}
 * - A {@link Gtk.SortListModel}, which sorts the base model according to
 * first name or last name, or whatever user preference
 * - A {@link Gtk.FilterListModel} to filter out contacts using a
 * {@link Folks.Query}, so a user can filter contacts with the search entry
 */
public class Contacts.Store : GLib.Object {

  public signal void quiescent ();
  public signal void prepared ();

  public IndividualAggregator aggregator { get; private set; }
  public BackendStore backend_store { get { return this.aggregator.backend_store; } }

  // Base list model, built from all contacts we obtain through libfolks
  private GLib.ListStore base_model = new ListStore (typeof (Individual));

  // Sorting list model (note that the sorter is public)
  private Gtk.SortListModel sort_model;
  public IndividualSorter sorter { get; private set; }

  // Filtering list model
  private Gtk.FilterListModel filter_model;
  public QueryFilter query_filter { get; private set; }
  public ManualFilter manual_filter { get; private set; }

  /** The list of individuals after all sorting/filtering operations */
  public GLib.ListModel individuals {
    get { return this.filter_model; }
  }

  private GLib.ListStore _address_books = new GLib.ListStore (typeof (PersonaStore));
  public GLib.ListModel address_books {
    get { return this._address_books; }
  }

  public Gee.HashMultiMap<string, string> dont_suggest_link;

  private void read_dont_suggest_db () {
    this.dont_suggest_link.clear ();

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

    // Setup the backends
    var backend_store = BackendStore.dup ();
    // FIXME: we should just turn the "backends" property in folks into a
    // GListModel directly
    foreach (var backend in backend_store.enabled_backends.values) {
      foreach (var persona_store in backend.persona_stores.values)
        this._address_books.append (persona_store);
    }
    backend_store.backend_available.connect ((backend) => {
      foreach (var persona_store in backend.persona_stores.values)
        this._address_books.append (persona_store);
    });

    // Setup the individual aggregator
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
  }

  public Store (GLib.Settings settings, Folks.Query query) {
    // Create the sorting, filtering and selection models
    this.sorter = new IndividualSorter (settings);
    this.sort_model = new Gtk.SortListModel (this.base_model, this.sorter);
    this.sort_model.section_sorter = new IndividualSectionSorter ();

    var filter = new Gtk.EveryFilter ();
    this.query_filter = new QueryFilter (query);
    filter.append (this.query_filter);
    this.manual_filter = new ManualFilter ();
    filter.append (this.manual_filter);

    this.filter_model = new Gtk.FilterListModel (this.sort_model, filter);
  }

  private void on_individuals_changed_detailed (Gee.MultiMap<Individual?,Individual?> changes) {
    var to_add = new GenericArray<unowned Individual> ();
    var to_remove = new GenericArray<unowned Individual> ();

    foreach (var individual in changes.get_keys ()) {
      if (individual != null)
        to_remove.add (individual);
      foreach (var new_i in changes[individual]) {
        if (new_i != null && !to_add.find (new_i, null))
          to_add.add (new_i);
      }
    }

    debug ("Individuals changed: %d added, %d removed", to_add.length, to_remove.length);

    // Remove old individuals. It's not the most performance way of doing it,
    // but optimizing for it (and making it more comples) makes little sense.
    foreach (unowned var indiv in to_remove) {
      uint pos = 0;
      if (this.base_model.find (indiv, out pos)) {
        this.base_model.remove (pos);
      } else {
        debug ("Tried to remove individual '%s', but could't find it", indiv.display_name);
      }
    }

    // Add new individuals
    for (uint i = 0; i < to_add.length; i++) {
      unowned var indiv = to_add[i];
      if (indiv.personas.size == 0 || Utils.is_ignorable (indiv)) {
        to_add.remove_index_fast (i);
        i--;
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
          if (this.base_model.find (obj, out pos)) {
            this.base_model.items_changed (pos, 1, 1);
          }
        });
      }
    }
    this.base_model.splice (this.base_model.get_n_items (), 0, (Object[]) to_add.data);
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
    for (uint i = 0; i < this.individuals.get_n_items (); i++) {
      var individual = (Individual) this.individuals.get_item (i);
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

    for (uint i = 0; i < this.individuals.get_n_items (); i++) {
      var individual = (Individual) this.individuals.get_item (i);
      if (individual.id == id)
        return i;
    }

    return Gtk.INVALID_LIST_POSITION;
  }

  /**
   * Sets the primary address book. This will be used as the primary candidate
   * to store new contacts, and will prioritize personas coming from this store
   * when showing them.
   */
  public void set_primary_address_book (Edsf.PersonaStore e_store) {
    eds_source_registry.set_default_address_book (e_store.source);
    var settings = new GLib.Settings ("org.freedesktop.folks");
    settings.set_string ("primary-store", "eds:%s".printf (e_store.id));
  }

  public bool suggest_link_to (Individual self, Individual other) {
    if (non_linkable (self) || non_linkable (other))
      return false;

    if (!may_suggest_link (self, other))
      return false;

    /* Only connect main contacts with non-mainable contacts.
       non-main contacts can link to any other */
    return !Utils.has_main_persona (self) || !has_mainable_persona (other);
  }

  // These are "regular" address book contacts, i.e. they contain a
  // persona that would be "main" if that persona was the primary store
  private bool has_mainable_persona (Individual individual) {
    foreach (var p in individual.personas) {
      if (p.store.type_id == "eds" &&
          !Utils.persona_is_google_other (p))
        return true;
    }
    return false;
  }

  // We never want to suggest linking to google contacts that
  // are part of "Other Contacts"
  private bool non_linkable (Individual individual) {
    bool all_unlinkable = true;

    foreach (var p in individual.personas) {
      if (!Utils.persona_is_google_other (p))
        all_unlinkable = false;
    }

    return all_unlinkable;
  }
}
