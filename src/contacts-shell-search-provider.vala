/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
using Gee;

[DBus (name = "org.gnome.Shell.SearchProvider2")]
public class Contacts.SearchProvider : Object {
  SearchProviderApp app;
  Store store;
  Gee.HashMap<string, Contact> contacts_map;
  private uint next_id;

  public SearchProvider (SearchProviderApp app) {
    this.app = app;
    ensure_eds_accounts ();
    store = new Store ();
    contacts_map = new Gee.HashMap<string, Contact> ();
    next_id = 0;

    store.changed.connect ( (c) => {
	contacts_map.set(c.get_data<string> ("search-id"), c);
      });
    store.added.connect ( (c) => {
	var id = next_id++.to_string ();
	c.set_data ("search-id", id);
	contacts_map.set(id, c);
      });
    store.removed.connect ( (c) => {
	contacts_map.unset(c.get_data<string> ("search-id"));
      });
  }

  private static int compare_contacts (Contact a, Contact b) {
    int a_prio = a.is_main ? 0 : -1;
    int b_prio = b.is_main ? 0 : -1;

    if (a_prio > b_prio)
      return -1;
    if (a_prio < b_prio)
      return 1;

    if (is_set (a.display_name) && is_set (b.display_name))
      return a.display_name.collate (b.display_name);

    // Sort empty names last
    if (is_set (a.display_name))
      return -1;
    if (is_set (b.display_name))
      return 1;

    return 0;
  }

  private async string[] do_search (string[] terms) {
    app.hold ();
    string[] normalized_terms =
    Utils.canonicalize_for_search (string.joinv(" ", terms)).split(" ");

    var matches = new ArrayList<Contact> ();
    foreach (var c in store.get_contacts ()) {
      if (c.is_hidden)
	continue;

      if (c.contains_strings (normalized_terms))
	matches.add (c);
    }

    matches.sort((CompareDataFunc<Contact>) compare_contacts);

    var results = new string[matches.size];
    for (int i = 0; i < matches.size; i++)
      results[i] = matches[i].get_data ("search-id");
    app.release ();
    return results;
  }

  public async string[] GetInitialResultSet (string[] terms) {
    warning ("GetInitialResultSet %s", string.joinv ("; ", terms));
    return yield do_search (terms);
  }

  public async string[] GetSubsearchResultSet (string[] previous_results,
					       string[] new_terms) {
    warning ("GetSubsearchResultSet %s", string.joinv ("; ", new_terms));
    return yield do_search (new_terms);
  }

  private async HashTable<string, Variant>[] get_metas (owned string[] ids) {
    app.hold ();
    var results = new ArrayList<HashTable> ();
    foreach (var id in ids) {
      var contact = contacts_map.get (id);

      if (contact == null)
        continue;

      var meta = new HashTable<string, Variant> (str_hash, str_equal);
      meta.insert ("id", new Variant.string (id));

      meta.insert ("name", new Variant.string (contact.display_name));

      if (contact.serializable_avatar_icon != null)
        meta.insert ("gicon", new Variant.string (contact.serializable_avatar_icon.to_string ()));
      else if (contact.avatar_icon_data != null)
        meta.insert ("icon-data", contact.avatar_icon_data);
      else
        meta.insert ("gicon", new Variant.string (new ThemedIcon ("avatar-default").to_string ()));
      results.add (meta);
    }
    app.release ();
    warning ("GetResultMetas: RETURNED");
    return results.to_array ();
  }

  public async HashTable<string, Variant>[] GetResultMetas (string[] ids) {
    warning ("GetResultMetas: %s", string.joinv ("; ", ids));
    return yield get_metas (ids);
  }

  public void ActivateResult (string search_id, string[] terms, uint32 timestamp) {
    app.hold ();

    warning ("ActivateResult: %s", search_id);

    var contact = contacts_map.get (search_id);

    if (contact == null) {
      app.release ();
      return;
    }

    string id = contact.individual.id;
    try {
      if (!Process.spawn_command_line_async ("gnome-contacts -i " + id))
        stderr.printf ("Failed to launch contact with id '%s'\n", id);
    } catch (SpawnError e) {
      stderr.printf ("Failed to launch contact with id '%s'\n", id);
    }

    app.release ();
  }

  public void LaunchSearch (string[] terms, uint32 timestamp) {
    app.hold ();

    debug ("LaunchSearch (%s)", string.joinv (", ", terms));

    try {
      string[] args = {};
      args += "gnome-contacts";
      args += "--search";
      args += string.joinv (" ", terms);
      if (!Process.spawn_async (null, args, null, SpawnFlags.SEARCH_PATH, null, null))
	stderr.printf ("Failed to launch Contacts for search\n");
    } catch (SpawnError error) {
      stderr.printf ("Failed to launch Contacts for search\n");
      warning (error.message);
    }

    app.release ();
  }
}

public class Contacts.SearchProviderApp : GLib.Application {
  public SearchProviderApp () {
    Object (application_id: "org.gnome.Contacts.SearchProvider",
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
