/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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

  // TRANSLATORS: This is a field which contains a name decomposed in several
  // parts, rather than a single freeform string for the full name
  public override string display_name { get { return _("Structured name"); } }

  public override string? icon_name { get { return null; } }

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
      assert (persona is NameDetails);
      persona.bind_property ("structured-name", this, "structured-name");
      this._structured_name = ((NameDetails) persona).structured_name;
    }
    this.original_structured_name = this.structured_name;
  }

  public override Value? to_value () {
    return (this.is_empty)? null : this.structured_name;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is NameDetails) {
    yield ((NameDetails) this.persona).change_structured_name (this.structured_name);
  }

  public override Variant? to_gvariant () {
    if (this.is_empty)
      return null;
    return new Variant ("(sssss)",
                        this.structured_name.family_name,
                        this.structured_name.given_name,
                        this.structured_name.additional_names,
                        this.structured_name.prefixes,
                        this.structured_name.suffixes);
  }

  public override void apply_gvariant (Variant variant,
                                       bool mark_dirty = true)
      requires (variant.get_type ().equal (new VariantType ("(sssss)"))) {

    string family_name, given_name, additional_names, prefixes, suffixes;
    variant.get ("(sssss)",
                 out family_name,
                 out given_name,
                 out additional_names,
                 out prefixes,
                 out suffixes);

    var structured_name = new StructuredName (family_name,
                                              given_name,
                                              additional_names,
                                              prefixes,
                                              suffixes);
    if (!mark_dirty) {
      this.original_structured_name = structured_name;
    }
    this.structured_name = structured_name;
  }
}
