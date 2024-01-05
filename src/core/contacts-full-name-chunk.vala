/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A {@link Chunk} that represents the full name of a contact as a single
 * string (contrary to the structured name, where the name is split up in the
 * several constituent parts}.
 */
public class Contacts.FullNameChunk : Chunk {

  private string original_full_name = "";

  public string full_name {
    get { return this._full_name; }
    set {
      if (this._full_name == value)
        return;

      bool was_empty = this.is_empty;
      bool was_dirty = this.dirty;
      this._full_name = value;
      notify_property ("full-name");
      if (this.is_empty != was_empty)
        notify_property ("is-empty");
      if (was_dirty != this.dirty)
        notify_property ("dirty");
    }
  }
  private string _full_name = "";

  public override string property_name { get { return "full-name"; } }

  public override string display_name { get { return _("Full name"); } }

  public override string? icon_name { get { return null; } }

  public override bool is_empty { get { return this._full_name.strip () == ""; } }

  public override bool dirty {
    get { return this.full_name.strip () != this.original_full_name.strip (); }
  }

  construct {
    if (persona != null) {
      assert (persona is NameDetails);
      persona.bind_property ("full-name", this, "full-name");
      this._full_name = ((NameDetails) persona).full_name;
    }
    this.original_full_name = this.full_name;
  }

  public FullNameChunk.from_gvariant (GLib.Variant variant) {
    unowned var fn = variant.get_string ();
    Object (persona: null, full_name: fn);
  }

  public override Value? to_value () {
    return this.full_name;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is NameDetails) {
    yield ((NameDetails) this.persona).change_full_name (this.full_name);
  }

  public override Variant? to_gvariant () {
    if (this.full_name == "")
      return null;
    return new Variant.string (this.full_name);
  }

  public override void apply_gvariant (Variant variant,
                                       bool mark_dirty = true)
      requires (variant.get_type ().equal (VariantType.STRING)) {

    unowned string full_name = variant.get_string ();
    if (!mark_dirty) {
      this.original_full_name = full_name;
    }
    this.full_name = full_name;
  }
}
