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
 * A {@link Chunk} that represents the full name of a contact as a single
 * string (contrary to the structured name, where the name is split up in the
 * several constituent parts}.
 */
public class Contacts.FullNameChunk : Chunk {

  public string full_name {
    get { return this._full_name; }
    set {
      if (this._full_name == value)
        return;

      bool was_empty = this.is_empty;
      this._full_name = value;
      notify_property ("full-name");
      if (this.is_empty != was_empty)
        notify_property ("is-empty");
    }
  }
  private string _full_name = "";

  public override string property_name { get { return "full-name"; } }

  public override bool is_empty { get { return this._full_name.strip () == ""; } }

  construct {
    if (persona != null) {
      return_if_fail (persona is NameDetails);
      persona.bind_property ("full-name", this, "full-name", BindingFlags.SYNC_CREATE);
    }
  }

  public override Value? to_value () {
    return this.full_name;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is NameDetails) {
    yield ((NameDetails) this.persona).change_full_name (this.full_name);
  }
}
