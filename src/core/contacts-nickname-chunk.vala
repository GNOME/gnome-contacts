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
 * A {@link Chunk} that represents the nickname of a contact.
 */
public class Contacts.NicknameChunk : Chunk {

  private string original_nickname = "";

  public string nickname {
    get { return this._nickname; }
    set {
      if (this._nickname == value)
        return;

      bool was_empty = this.is_empty;
      bool was_dirty = this.dirty;
      this._nickname = value;
      notify_property ("nickname");
      if (this.is_empty != was_empty)
        notify_property ("is-empty");
      if (was_dirty != this.dirty)
        notify_property ("dirty");
    }
  }
  private string _nickname = "";

  public override string property_name { get { return "nickname"; } }

  public override bool is_empty { get { return this._nickname.strip () == ""; } }

  public override bool dirty {
    get { return this.nickname.strip () != this.original_nickname.strip (); }
  }

  construct {
    if (persona != null) {
      return_if_fail (persona is NameDetails);
      persona.bind_property ("nickname", this, "nickname");
      this._nickname = ((NameDetails) persona).nickname;
    }
    this.original_nickname = this.nickname;
  }

  public override Value? to_value () {
    return this.nickname;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is NameDetails) {

    yield ((NameDetails) this.persona).change_nickname (this.nickname);
  }
}
