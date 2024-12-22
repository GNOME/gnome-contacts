/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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

  public override string? icon_name { get { return "image-round-symbolic"; } }

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
