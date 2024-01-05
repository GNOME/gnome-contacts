/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * The TypeDescriptor is the internal representation of a property's type.
 */
public class Contacts.TypeDescriptor : Object {

  public const string X_GOOGLE_LABEL = "x-google-label";

  private enum Source {
    VCARD,
    OTHER,
    CUSTOM;

    public unowned string to_string () {
      switch (this) {
        case VCARD:
          return "vcard";
        case OTHER:
          return "other";
        case CUSTOM:
          return "custom";
      }
      return "INVALID";
    }
  }

  private Source source;
  public string? name = null;
  public string[]? vcard_types = null;

  /**
   * Returns the translated name for this property.
   */
  public string display_name {
    get {
      if (is_custom ())
        return this.name;
      return dgettext (Config.GETTEXT_PACKAGE, this.name);
    }
  }

  /**
   * Creates a TypeDescriptor which is mappable to the given VCard Type strings.
   */
  public TypeDescriptor.vcard (string untranslated_name, string[] types) {
    this.source = Source.VCARD;
    this.name = untranslated_name;
    this.vcard_types = types;
  }

  /**
   * Creates a TypeDescriptor with a custom label
   */
  public TypeDescriptor.custom (string name) {
    this.source = Source.CUSTOM;
    this.name = name;
  }

  /**
   * Creates a TypeDescriptor which represents all non-representable types.
   */
  public TypeDescriptor.other () {
    this.source = Source.OTHER;
    this.name = N_("Other");
  }

  public bool is_custom () {
    return this.source == Source.CUSTOM;
  }

  public void save_to_field_details (AbstractFieldDetails details) {
    debug ("Saving type %s to AbsractFieldDetails", to_string ());
    details.parameters = adapt_parameters (details.parameters);
  }

  public Gee.MultiMap<string, string> adapt_parameters (Gee.MultiMap<string, string> parameters) {
    var result = new Gee.HashMultiMap<string, string> ();

    // Check whether PREF VCard "flag" is set
    bool has_pref = false;
    foreach (var val in parameters["type"]) {
      if (val.ascii_casecmp ("PREF") == 0) {
        has_pref = true;
        break;
      }
    }

    // Copy over all parameters, execept the ones we're going to create ourselves
    foreach (var param in parameters.get_keys ()) {
      if (param != "type" && param != X_GOOGLE_LABEL)
        foreach (var val in parameters[param])
          result[param] = val;
    }

    // Set the type based on our Source
    switch (this.source) {
      case Source.VCARD:
        foreach (var type in this.vcard_types)
          if (type != null)
            result["type"] = type;
        break;
      case Source.OTHER:
        result["type"] = "OTHER";
        break;
      case Source.CUSTOM:
        result["type"] = "OTHER";
        result[X_GOOGLE_LABEL] = this.name;
        break;
    }

    if (has_pref)
      result["type"] = "PREF";

    return result;
  }

  /**
   * Converts the TypeDescriptor to a string. Should only be used for debugging.
   */
  public string to_string () {
    StringBuilder str = new StringBuilder ("{ ");
    str.append_printf (".source = %s, ", this.source.to_string ());
    str.append_printf (".name = \"%s\", ", this.name);
    str.append_printf (".display_name = \"%s\", ", this.display_name);
    if (this.vcard_types == null)
      str.append_printf (".vcard_types = NULL }");
    else
      str.append_printf (".vcard_types = [ %s }", string.joinv (", ", this.vcard_types));
    return str.str;
  }
}
