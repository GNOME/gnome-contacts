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
 * A {@link Chunk} that represents the birthday of a contact (similar to
 * {@link Folks.BirthdayDetails}}.
 */
public class Contacts.BirthdayChunk : Chunk {

  public DateTime? birthday {
    get { return this._birthday; }
    set {
      if (this._birthday == null && value == null)
        return;

      if (this._birthday != null && value != null
          && this._birthday.equal (value.to_utc ()))
        return;

      this._birthday = (value != null)? value.to_utc () : null;
      notify_property ("birthday");
      notify_property ("is-empty");
    }
  }
  private DateTime? _birthday = null;

  public override string property_name { get { return "birthday"; } }

  public override bool is_empty { get { return this.birthday == null; } }

  construct {
    if (persona != null) {
      return_if_fail (persona is BirthdayDetails);
      persona.bind_property ("birthday", this, "birthday", BindingFlags.SYNC_CREATE);
    }
  }

  public override Value? to_value () {
    return this.birthday;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is BirthdayDetails) {
    yield ((BirthdayDetails) this.persona).change_birthday (this.birthday);
  }
}
