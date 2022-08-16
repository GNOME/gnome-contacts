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

public class Contacts.AliasChunk : Chunk {

  public string alias {
    get { return this._alias; }
    set {
      if (this._alias == value)
        return;

      bool was_empty = this.is_empty;
      this._alias = value;
      notify_property ("alias");
      if (this.is_empty != was_empty)
        notify_property ("is-empty");
    }
  }
  private string _alias = "";

  public override string property_name { get { return "alias"; } }

  public override bool is_empty { get { return this._alias.strip () == ""; } }

  construct {
    if (persona != null) {
      return_if_fail (persona is AliasDetails);
      persona.bind_property ("alias", this, "alias", BindingFlags.SYNC_CREATE);
    }
  }

  public override Value? to_value () {
    return this.alias;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is AliasDetails) {

    yield ((AliasDetails) this.persona).change_alias (this.alias);
  }
}
