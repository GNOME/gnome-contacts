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

  /**
   * Saves the type decribed by this object to the given parameters (as found
   * in the parameters property of a {@link Folks.AbstractFieldDetails} object.
   *
   * If old_parameters is specified, it will also copy over all fields (that
   * not related to the type of the property).
   *
   * @param old_parameters: The previous parameters to base on, or null if none.
   */
  public MultiMap<string, string> add_type_to_parameters (MultiMap<string, string>? old_parameters) {
    debug ("Saving type %s", to_string ());

    var new_parameters = new HashMultiMap<string, string> ();

    // Check whether PREF VCard "flag" is set
    bool has_pref = false;
    if (old_parameters != null) {
      has_pref = TypeDescriptor.parameters_have_type_pref (old_parameters);

      // Copy over all parameters, execept the ones we're going to create ourselves
      foreach (var param in old_parameters.get_keys ()) {
        if (param != "type" && param != X_GOOGLE_LABEL)
          foreach (var val in old_parameters[param])
            new_parameters[param] = val;
      }
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

    return new_parameters;
  }

  public static bool parameters_have_type_pref (MultiMap<string, string> parameters) {
    foreach (var val in parameters["type"])
      if (val.ascii_casecmp ("PREF") == 0)
        return true;

    return false;
  }

  /**
   * Checks whether the values related to a {@link TypeDescriptor} in the given
   * parameters (as one might find in a {@link Folks.AbstractFieldDetails}) are
   * equal.
   *
   * @param parameters_a: The first parameters multimap to compare
   * @param parameters_b: The second parameters multimap to compare
   *
   * @return: Whether the type parameters ("type" and "PREF") are equal
   */
  public static bool check_type_parameters_equal (MultiMap<string, string> parameters_a,
                                                  MultiMap<string, string> parameters_b) {
    // First check if some "PREF" value changed
    if (TypeDescriptor.parameters_have_type_pref (parameters_a)
        != TypeDescriptor.parameters_have_type_pref (parameters_b))
      return false;

    // Next, check for any custom Google property labels
    var google_label_a = Utils.get_first<string> (parameters_a[X_GOOGLE_LABEL]);
    var google_label_b = Utils.get_first<string> (parameters_b[X_GOOGLE_LABEL]);
    if (google_label_a != null || google_label_b != null) {
      // Note that we do a case-sensitive comparison for custom labels
      return google_label_a == google_label_b;
    }

    // Finally, check the type parameters
    var types_a = new ArrayList<string>.wrap (parameters_a["type"].to_array ());
    var types_b = new ArrayList<string>.wrap (parameters_b["type"].to_array ());

    if (types_a.size != types_b.size)
      return false;

    // Now we check if types are esual. Note that we might be a bit more strict
    // than truly necessary, but from a UI perspective they are still the same
    types_a.sort ();
    types_b.sort ();
    for (int i = 0; i < types_a.size; i++)
      if (types_a[i].ascii_casecmp (types_b[i]) != 0)
        return false;

    return true;
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
