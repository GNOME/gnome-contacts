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

using Gtk;
using Folks;
using Gee;

public class Contacts.Store : GLib.Object {
  public signal void added (Individual c);
  public signal void removed (Individual c);
  public signal void quiescent ();
  public signal void prepared ();

  public IndividualAggregator aggregator { get; private set; }
  public BackendStore backend_store { get { return this.aggregator.backend_store; } }

  public Gee.HashMultiMap<string, string> dont_suggest_link;

#if HAVE_TELEPATHY
  public TelepathyGLib.Account? caller_account { get; private set; default = null; }
#endif

  public bool is_quiescent {
    get { return this.aggregator.is_quiescent; }
  }

  public bool is_prepared {
    get { return this.aggregator.is_prepared; }
  }

  private void read_dont_suggest_db () {
    dont_suggest_link.clear ();
    try {
      var path = Path.build_filename (Environment.get_user_config_dir (), "gnome-contacts", "dont_suggest.db");
      string contents;
      if (FileUtils.get_contents (path, out contents)) {
	var rows = contents.split ("\n");
	foreach (var r in rows) {
	  var ids = r.split (" ");
	  if (ids.length == 2) {
	    dont_suggest_link.set (ids[0], ids[1]);
	  }
	}
      }
    } catch (GLib.Error e) {
      if (!(e is FileError.NOENT))
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
	foreach (var value in dont_suggest_link.get (key)) {
	  s.append_printf ("%s %s\n", key, value);
	}
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
    dont_suggest_link = new Gee.HashMultiMap<string, string> ();
    read_dont_suggest_db ();

    var backend_store = BackendStore.dup ();

    this.aggregator = IndividualAggregator.dup_with_backend_store (backend_store);
    aggregator.notify["is-quiescent"].connect ( (obj, pspec) => {
	// We seem to get this before individuals_changed, so hack around it
	Idle.add( () => {
	    this.quiescent ();
	    return false;
	  });
      });

    aggregator.notify["is-prepared"].connect ( (obj, pspec) => {
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

  private void on_individuals_changed_detailed (MultiMap<Individual?,Individual?> changes) {
    var to_add = new HashSet<Individual> ();
    var to_remove = new HashSet<Individual> ();
    foreach (var i in changes.get_keys()) {
      if (i != null)
        to_remove.add (i);
      foreach (var new_i in changes[i]) {
        to_add.add (new_i);
      }
    }

    debug ("Individuals changed: %d old, %d new", to_add.size, to_remove.size);

    // Add new individuals
    foreach (var i in to_add) {
      if (i.personas.size > 0)
        added (i);
    }

    // Remove old individuals
    foreach (var i in to_remove) {
      removed (i);
    }
  }

  public Collection<Individual> get_contacts () {
    return aggregator.individuals.values.read_only_view;
  }

  public async Individual? find_contact (Query query) {
    // Wait that the store gets quiescent if it isn't already
    if (!is_quiescent) {
      ulong signal_id;
      SourceFunc callback = find_contact.callback;
      signal_id = this.quiescent.connect ( () => {
        callback();
      });
      yield;
      disconnect (signal_id);
    }

    Individual? matched = null;
    // We search for the closest matching Individual
    uint strength = 0;
    foreach (var i in this.aggregator.individuals.values) {
      var this_strength = query.is_match(i);
      if (this_strength > strength) {
        matched = i;
        strength = this_strength;
      }
    }

    return matched;
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
