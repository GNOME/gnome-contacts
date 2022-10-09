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
 * A {@link Chunk} that represents the structured name of a contact.
 *
 * The structured represents a full name split in its constituent parts (given
 * name, family name, etc.)
 */
public class Contacts.StructuredNameChunk : Chunk {

  private StructuredName original_structured_name;

  public StructuredName structured_name {
    get { return this._structured_name; }
    set {
      if (this._structured_name == value)
        return;
      if (this._structured_name != null && value != null
          && this._structured_name.equal (value))
        return;

      bool was_empty = this.is_empty;
      this._structured_name = value;
      notify_property ("structured-name");
      if (this.is_empty != was_empty)
        notify_property ("is-empty");
    }
  }
  private StructuredName _structured_name = new StructuredName.simple (null, null);

  public override string property_name { get { return "structured-name"; } }

  public override bool is_empty {
    get {
      return this._structured_name == null || this._structured_name.is_empty ();
    }
  }

  public override bool dirty {
    get { return !this.original_structured_name.equal (this._structured_name); }
  }

  construct {
    if (persona != null) {
      return_if_fail (persona is NameDetails);
      persona.bind_property ("structured-name", this, "structured-name");
      this._structured_name = ((NameDetails) persona).structured_name;
    }
    this.original_structured_name = this.structured_name;
  }

  public override Value? to_value () {
    return this.structured_name;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is NameDetails) {
    yield ((NameDetails) this.persona).change_structured_name (this.structured_name);
  }
}
