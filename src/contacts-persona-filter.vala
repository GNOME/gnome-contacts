/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A custom GtkFilter to filter out {@link Folks.Persona}s, for example to
 * exclude certain types of persona stores.
 */
public class Contacts.PersonaFilter : Gtk.Filter {

  public string[] ignored_store_types {
    get { return this._ignored_store_types; }
    set {
      if (value == null && this.ignored_store_types == null)
        return;
      if (GLib.strv_equal (this._ignored_store_types, value))
        return;
      // notify ignored-store-types
    }
  }
  private string[] _ignored_store_types = { "key-file", };

  public override bool match (GLib.Object? item)
      requires (item is Persona) {

    unowned var persona = item as Persona;
    return match_persona_store_type (persona);
  }

  private bool match_persona_store_type (Persona persona) {
    return !(persona.store.type_id in this.ignored_store_types);
  }

  public override Gtk.FilterMatch get_strictness () {
    return Gtk.FilterMatch.SOME;
  }
}
