/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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

  public override bool match (GLib.Object? item) {
    unowned var persona = item as Persona;
    return_val_if_fail (persona != null, false);

    return match_persona_store_type (persona);
  }

  private bool match_persona_store_type (Persona persona) {
    return !(persona.store.type_id in this.ignored_store_types);
  }

  public override Gtk.FilterMatch get_strictness () {
    return Gtk.FilterMatch.SOME;
  }
}
