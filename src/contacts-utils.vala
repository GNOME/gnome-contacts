/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

namespace Contacts.Utils {

  public T? get_first<T> (Gee.Collection<T> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
  }

  public string[] get_stock_avatars () {
    string[] files = {};
    var system_data_dirs = Environment.get_system_data_dirs ();
    foreach (var data_dir in system_data_dirs) {
      var path = Path.build_filename (data_dir, "pixmaps", "faces");
      Dir? dir = null;
      try {
        dir = Dir.open (path);
      } catch (Error e) {
        debug ("Couldn't open stock avatars folder \"%s\": %s", path, e.message);
      }
      if (dir != null) {
        string? face;
        while ((face = dir.read_name ()) != null) {
          var filename = Path.build_filename (path, face);
          files += filename;
        }
      }
    };
    return files;
  }

  public bool persona_is_main (Persona persona) {
    var store = persona.store;
    if (!store.is_primary_store)
      return false;

    // Mark google contacts not in "My Contacts" as non-main
    return !persona_is_google_other (persona);
  }

  public bool has_main_persona (Individual individual) {
    var result = false;
    foreach (var p in individual.personas) {
      result |= (p.store.is_primary_store && !persona_is_google_other (p));
    }
    return result;
  }

  public bool is_ignorable (Individual individual) {
    foreach (var persona in individual.personas) {
      // Filter out pure key-file persona individuals as these are not very interesting
      if (persona.store.type_id == "key-file")
        continue;

      // Filter out uncertain things like link-local xmpp
      if (persona.store.type_id == "telepathy" &&
          persona.store.trust_level == PersonaStoreTrust.NONE)
        continue;

      // If we have any other kind of persona, don't ignore
      return false;
    }

    return true;
  }

  /* We claim something is "removable" if at least one persona is removable,
  that will typically unlink the rest. */
  public bool can_remove_personas (Individual individual) {
    foreach (var p in individual.personas)
      if (p.store.can_remove_personas == MaybeBool.TRUE)
        return true;

    return false;
  }

  public ListModel personas_as_list_model (Individual individual) {
    var personas = new ListStore (typeof(Persona));
    foreach (var persona in individual.personas)
      personas.append (persona);
    return personas;
  }

  public string format_persona_stores (Individual individual) {
    string stores = "";
    bool first = true;
    foreach (var p in individual.personas) {
      if (!first)
        stores += ", ";
      stores += format_persona_store_name_for_contact (p);
      first = false;
    }
    return stores;
  }

  public string format_persona_store_name (PersonaStore store) {
    if (store.type_id == "eds") {
      // Special-case the local address book
      if (store.id == "system-address-book")
        return _("Local Address Book");

      string? eds_name = lookup_esource_name_by_uid (store.id);
      if (eds_name != null)
        return eds_name;
    }

    return store.display_name;
  }

  public bool persona_is_google (Persona persona) {
    return persona.store.type_id == "eds" && esource_uid_is_google (persona.store.id);
  }

  /**
   * Return true only for personas which are in a Google address book, but which
   * are not in the user's "My Contacts" group in the address book.
   */
  public bool persona_is_google_other (Persona persona) {
    if (!persona_is_google (persona))
      return false;

    unowned var p = persona as Edsf.Persona;
    return p != null && !p.in_google_personal_group;
  }

  public string format_persona_store_name_for_contact (Persona persona) {
    unowned var store = persona.store;
    if (store.type_id == "eds") {
      if (persona_is_google_other (persona))
        return _("Google");

      string? eds_name = lookup_esource_name_by_uid_for_contact (store.id);
      if (eds_name != null)
        return eds_name;
    }

    return store.display_name;
  }

  /**
   * A function that mostly useful in a <closure> with a single string
   * argument, for example to hide a GtkLabel when its contents are empty.
   */
  public bool string_is_non_empty_closure (GLib.Object ignore, string? str) {
    return (str != null) && (str != "");
  }
}
