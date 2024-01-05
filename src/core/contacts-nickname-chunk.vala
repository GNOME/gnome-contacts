/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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

  public override string display_name { get { return _("Nickname"); } }

  public override string? icon_name { get { return "avatar-default-symbolic"; } }

  public override bool is_empty { get { return this._nickname.strip () == ""; } }

  public override bool dirty {
    get { return this.nickname.strip () != this.original_nickname.strip (); }
  }

  construct {
    if (persona != null) {
      assert (persona is NameDetails);
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

  public override Variant? to_gvariant () {
    if (this.nickname == "")
      return null;
    return new Variant.string (this.nickname);
  }

  public override void apply_gvariant (Variant variant,
                                       bool mark_dirty = true)
      requires (variant.get_type ().equal (VariantType.STRING)) {

    unowned string nickname = variant.get_string ();
    if (!mark_dirty) {
      this.original_nickname = nickname;
    }
    this.nickname = nickname;
  }
}
