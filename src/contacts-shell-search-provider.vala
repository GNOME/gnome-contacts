/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

[DBus (name = "org.gnome.Shell.SearchProvider2")]
public class Contacts.SearchProvider : Object {
  private SearchProviderApp app;
  private IndividualAggregator aggregator;
  private SimpleQuery query;
  private Variant serialized_fallback_icon;

  public SearchProvider (SearchProviderApp app) {
    // Do this first, since this will be the slowest (and is async anyway)
    this.aggregator = IndividualAggregator.dup ();
    this.aggregator.prepare.begin ();

    this.app = app;
    this.serialized_fallback_icon = new ThemedIcon.from_names ({"avatar-default-symbolic"}).serialize ();;

    var matched_fields = Query.MATCH_FIELDS_NAMES;
    foreach (var field in Query.MATCH_FIELDS_ADDRESSES)
      matched_fields += field;
    this.query = new SimpleQuery ("", matched_fields);

    if (!ensure_eds_accounts (false))
      this.app.quit ();
  }

  public async string[] GetInitialResultSet (string[] terms) throws Error {
    /* Wait that the aggregator has prepared some data or the search will be empty */
    if (!this.aggregator.is_quiescent) {
      var id = this.aggregator.notify["is-quiescent"].connect(() => {
        GetInitialResultSet.callback ();
      });

      // Add timeout for 1.5s so we can check if we already have some results
      var timeout = Timeout.add (1500, () => {
        GetInitialResultSet.callback ();
        return false;
      });
      yield;
      Source.remove (timeout);
      this.aggregator.disconnect (id);

      var results = yield do_search (terms);
      if (results.length == 0) {
        // We still don't have any results wait some more
        return yield GetInitialResultSet (terms);
      } else {
        return results;
      }
    } else {
      return yield do_search (terms);
    }
  }

  public async string[] GetSubsearchResultSet (string[] previous_results, string[] new_terms)
      throws Error {
    return yield GetInitialResultSet (new_terms);
  }

  private async string[] do_search (string[] terms) throws Error {
    this.app.hold ();

    // Make the query and search view
    query.query_string = string.joinv(" ", terms);
    var search_view = new SearchView (aggregator, query);
    try {
      yield search_view.prepare ();
    } catch (Error e) {
      error ("Couldn't load SearchView: %s", e.message);
    }
    var results = new string[search_view.individuals.size];
    var i = 0;
    foreach (var individual in search_view.individuals) {
      results[i] = individual.id;
      i++;
    }

    this.app.release ();
    return results;
  }

  public async HashTable<string, Variant>[] GetResultMetas (string[] ids) throws Error {
    return yield get_metas (ids);
  }

  private async HashTable<string, Variant>[] get_metas (owned string[] ids) throws Error {
    this.app.hold ();

    var results = new Gee.ArrayList<HashTable> ();
    foreach (unowned string id in ids) {
      Individual indiv = null;
      try {
        indiv = yield aggregator.look_up_individual (id);
      } catch (Error e) {
        continue;
      }
      if (indiv == null)
        continue;

      var meta = new HashTable<string, Variant> (str_hash, str_equal);
      meta["id"] = new Variant.string (id);
      meta["name"] = new Variant.string (indiv.display_name);
      meta["icon"] = (indiv.avatar != null)? indiv.avatar.serialize () : serialized_fallback_icon;

      // Make a description based the first email address/phone nr/... we can find
      var description = new StringBuilder ();

      var email = Utils.get_first<EmailFieldDetails> (indiv.email_addresses);
      if (email != null && email.value != null && email.value != "")
        description.append (email.value);

      var phone = Utils.get_first<PhoneFieldDetails> (indiv.phone_numbers);
      if (phone != null && phone.value != null && phone.value != "") {
        if (description.len > 0)
          description.append (" / ");
        description.append (phone.value);
      }

      meta["description"] = description.str;

      results.add (meta);
    }
    this.app.release ();
    return results.to_array ();
  }

  public void ActivateResult (string id, string[] terms, uint32 timestamp) throws Error {
    this.app.hold ();

    try {
      Process.spawn_command_line_async ("gnome-contacts -i " + id);
    } catch (SpawnError e) {
      stderr.printf ("Failed to launch contact with id '%s': %s\n.", id, e.message);
    }
    this.app.release ();
  }

  public void LaunchSearch (string[] terms, uint32 timestamp) throws Error {
    this.app.hold ();

    debug ("LaunchSearch (%s)", string.joinv (", ", terms));

    try {
      string[] args = { "gnome-contacts", "--search" };
      args += string.joinv (" ", terms);
      Process.spawn_async (null, args, null, SpawnFlags.SEARCH_PATH, null, null);
    } catch (SpawnError error) {
      stderr.printf ("Failed to launch Contacts for search\n");
    }

    this.app.release ();
  }
}

public class Contacts.SearchProviderApp : GLib.Application {
  public SearchProviderApp () {
    Object (application_id: Config.APP_ID + ".SearchProvider",
            flags: ApplicationFlags.IS_SERVICE,
            inactivity_timeout: 10000);
  }

  public override bool dbus_register (GLib.DBusConnection connection, string object_path) {
    try {
      connection.register_object (object_path, new SearchProvider (this));
    } catch (IOError error) {
      stderr.printf ("Could not register service: %s", error.message);
      quit ();
    }
    return true;
  }

  public override void startup () {
    if (Environment.get_variable ("CONTACTS_SEARCH_PROVIDER_PERSIST") != null)
      hold ();
    base.startup ();
  }
}

int main () {
  return new Contacts.SearchProviderApp ().run ();
}
