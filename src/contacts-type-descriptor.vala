/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
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

using Gtk;
using Gee;
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

    public string to_string () {
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
  public TreeIter iter;

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
    debug ("Saving type %s", to_string ());

    var old_parameters = details.parameters;
    var new_parameters = new HashMultiMap<string, string> ();

    // Check whether PREF VCard "flag" is set
    bool has_pref = false;
    foreach (var val in old_parameters["type"]) {
      if (val.ascii_casecmp ("PREF") == 0) {
        has_pref = true;
        break;
      }
    }

    // Copy over all parameters, execept the ones we're going to create ourselves
    foreach (var param in old_parameters.get_keys ()) {
      if (param != "type" && param != X_GOOGLE_LABEL)
        foreach (var val in old_parameters[param])
          new_parameters[param] = val;
    }

    // Set the type based on our Source
    switch (this.source) {
      case Source.VCARD:
        foreach (var type in this.vcard_types)
          if (type != null)
            new_parameters["type"] = type;
        break;
      case Source.OTHER:
        new_parameters["type"] = "OTHER";
        break;
      case Source.CUSTOM:
        new_parameters["type"] = "OTHER";
        new_parameters[X_GOOGLE_LABEL] = this.name;
        break;
    }

    if (has_pref)
      new_parameters["type"] = "PREF";

    // We didn't crash 'n burn, so lets
    details.parameters = new_parameters;
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
