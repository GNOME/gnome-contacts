/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

public class Contacts.AliasChunk : Chunk {

  private string original_alias = "";

  public string alias {
    get { return this._alias; }
    set {
      if (this._alias == value)
        return;

      bool was_empty = this.is_empty;
      bool was_dirty = this.dirty;
      this._alias = value;
      notify_property ("alias");
      if (this.is_empty != was_empty)
        notify_property ("is-empty");
      if (was_dirty != this.dirty)
        notify_property ("dirty");
    }
  }
  private string _alias = "";

  public override string property_name { get { return "alias"; } }

  public override string display_name { get { return _("Alias"); } }

  public override string? icon_name { get { return null; } }

  public override bool is_empty { get { return this._alias.strip () == ""; } }

  public override bool dirty {
    get { return this.alias.strip () == this.original_alias.strip (); }
  }

  construct {
    if (persona != null) {
      assert (persona is AliasDetails);
      persona.bind_property ("alias", this, "alias");
      this._alias = ((AliasDetails) persona).alias;
    }
    this.original_alias = this.alias;
  }

  public override Value? to_value () {
    return this.alias;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is AliasDetails) {

    yield ((AliasDetails) this.persona).change_alias (this.alias);
  }

  public override Variant? to_gvariant () {
    return new Variant.string (this.alias);
  }

  public override void apply_gvariant (Variant variant,
                                       bool mark_dirty = true)
      requires (variant.get_type ().equal (VariantType.STRING)) {

    unowned string alias = variant.get_string ();
    if (!mark_dirty) {
      this.original_alias = alias;
    }
    this.alias = alias;
  }
}
