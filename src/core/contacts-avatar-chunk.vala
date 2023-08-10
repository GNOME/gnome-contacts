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

public class Contacts.AvatarChunk : Chunk {

  private LoadableIcon? original_avatar = null;

  public LoadableIcon? avatar {
    get { return this._avatar; }
    set {
      if (this._avatar == value)
        return;
      this._avatar = value;
      notify_property ("avatar");
      notify_property ("is-empty");
    }
  }
  private LoadableIcon? _avatar = null;

  public override string property_name { get { return "avatar"; } }

  public override string display_name { get { return _("Avatar"); } }

  public override string? icon_name { get { return "emblem-photos-symbolic"; } }

  public override bool is_empty { get { return this._avatar == null; } }

  public override bool dirty {
    get { return this.avatar != this.original_avatar; }
  }

  construct {
    if (persona != null) {
      assert (persona is AvatarDetails);
      persona.bind_property ("avatar", this, "avatar");
      this._avatar = ((AvatarDetails) persona).avatar;
    }
    this.original_avatar = this.avatar;
  }

  public override Value? to_value () {
    return this._avatar;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is AvatarDetails) {
    yield ((AvatarDetails) this.persona).change_avatar (this.avatar);
  }

  public override Variant? to_gvariant () {
    // FIXME: implement
    return null;
  }

  public override void apply_gvariant (Variant variant,
                                       bool mark_dirty = true) {
    // FIXME: implement
  }
}
