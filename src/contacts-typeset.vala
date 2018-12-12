/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
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

public class Contacts.TypeSet : Object  {
  const string X_GOOGLE_LABEL = "x-google-label";
  const int MAX_TYPES = 3;

  private struct VcardTypeMapping {
    unowned string display_name_u;
    unowned string types[3]; //MAX_TYPES
  }

  private class TypeDescriptor : Object {
    public string display_name; // Translated
    public VcardTypeMapping? vcard_mapping;
    public TreeIter iter; // Set if in_store
    public bool in_store;
  }

  // Dummy TypeDescriptor to mark the "Other..." store entry
  private static TypeDescriptor other_dummy = new TypeDescriptor ();

  // Map from translated display name to TypeDescriptor for all "standard" types
  private HashTable<unowned string, TypeDescriptor> display_name_hash;
  // List of VcardTypeMapping
  private Gee.List<VcardTypeMapping?> vcard_type_mappings;
  // Map from display name to TreeIter for all custom types
  private HashTable<string, TreeIter?> custom_hash;

  public Gtk.ListStore store;
  private TreeIter other_iter;

  private TypeSet () {
    display_name_hash = new HashTable<unowned string, TypeDescriptor> (str_hash, str_equal);
    this.vcard_type_mappings = new Gee.ArrayList<VcardTypeMapping?> ();
    custom_hash = new HashTable<string, TreeIter? > (str_hash, str_equal);

    store = new Gtk.ListStore (2,
                               // Display name or null for separator
                               typeof(string?),
                               // TypeDescriptor for standard types, null for custom
                               typeof (TypeDescriptor));
  }

  private void add_descriptor_to_store (TypeDescriptor descriptor, bool is_custom) {
    if (descriptor.in_store)
      return;

    descriptor.in_store = true;
    if (is_custom)
      this.store.insert_before (out descriptor.iter, null);
    else
      this.store.append (out descriptor.iter);

    store.set (descriptor.iter, 0, descriptor.display_name, 1, descriptor);
  }

  private void add_vcard_mapping (VcardTypeMapping vcard_mapping) {
    unowned string dn = dgettext (Config.GETTEXT_PACKAGE, vcard_mapping.display_name_u);
    TypeDescriptor descriptor = display_name_hash.lookup (dn);
    if (descriptor == null) {
      descriptor = new TypeDescriptor ();
      descriptor.display_name = dn;
      display_name_hash.insert (dn, descriptor);
    }

    if (descriptor.vcard_mapping == null)
      descriptor.vcard_mapping = vcard_mapping;

    this.vcard_type_mappings.add (vcard_mapping);
  }

  private void add_vcard_mapping_done (string[] standard_untranslated) {
    foreach (var untranslated in standard_untranslated) {
      var descriptor = display_name_hash.lookup (dgettext (Config.GETTEXT_PACKAGE, untranslated));
      if (descriptor != null)
        add_descriptor_to_store (descriptor, false);
      else
        error ("Internal error: Can't find display name %s in TypeSet data", untranslated);
    }

    store.append (out other_iter);
    /* Refers to the type of the detail, could be Home, Work or Other for email, and the same
     * for phone numbers, addresses, etc. */
    store.set (other_iter, 0, _("Other"), 1, other_dummy);
  }

  public void add_custom_label (string label, out TreeIter iter) {
    // If we add a custom name equal to one of the standard ones, reuse that one
    var descriptor = display_name_hash.lookup (label);
    if (descriptor != null) {
      add_descriptor_to_store (descriptor, true);
      iter = descriptor.iter;
      return;
    }

    if (label == _("Other")) {
      iter = other_iter;
      return;
    }

    unowned TreeIter? iterp = custom_hash.lookup (label);
    if (iterp != null) {
      iter = iterp;
      return;
    }

    store.insert_before (out iter, null);
    store.set (iter, 0, label, 1, null);
    custom_hash.insert (label, iter);
  }

  private unowned TypeDescriptor? lookup_descriptor_by_string (string str) {
    foreach (VcardTypeMapping? d in this.vcard_type_mappings) {
      if (d.types[1] == null) {
        unowned string dn = dgettext (Config.GETTEXT_PACKAGE, d.display_name_u);
        return display_name_hash.lookup (dn);
      }
    }

    return null;
  }

  private unowned TypeDescriptor? lookup_descriptor (AbstractFieldDetails detail) {
    var i = detail.get_parameter_values ("type");
    if (i == null || i.is_empty)
      return null;

    var list = new Gee.ArrayList<string> ();
    foreach (var s in detail.get_parameter_values ("type"))
      list.add (s.up ());

    // Make sure all items in the VcardTypeMapping is in the specified type, there might
    // be more, but we ignore them (so a HOME,FOO,PREF,BLAH contact still matches
    // the standard HOME one, but not HOME,FAX
    foreach (VcardTypeMapping? d in this.vcard_type_mappings) {
      bool all_found = true;
      for (int j = 0; j < MAX_TYPES && d.types[j] != null; j++) {
        if (!list.contains (d.types[j])) {
          all_found = false;
          break;
        }
      }
      if (all_found) {
        unowned string dn = dgettext (Config.GETTEXT_PACKAGE, d.display_name_u);
        return display_name_hash.lookup (dn);
      }
    }

    return null;
  }

  // Looks up (and creates if necessary) the type in the store
  public void lookup_type (AbstractFieldDetails detail, out TreeIter iter) {
    if (detail.parameters.contains (X_GOOGLE_LABEL)) {
      var label = Utils.get_first<string> (detail.parameters.get (X_GOOGLE_LABEL));
      add_custom_label (label, out iter);
      return;
    }

    unowned TypeDescriptor? d = lookup_descriptor (detail);
    if (d != null) {
      add_descriptor_to_store (d, true);
      iter = d.iter;
    } else {
      iter = other_iter;
    }
  }

  public void lookup_type_by_string (string type, out TreeIter iter) {
    unowned TypeDescriptor? d = lookup_descriptor_by_string (type);
    iter = (d != null)? d.iter : this.other_iter;
  }

  public string format_type (AbstractFieldDetails detail) {
    if (detail.parameters.contains (X_GOOGLE_LABEL))
      return Utils.get_first<string> (detail.parameters[X_GOOGLE_LABEL]);

    unowned TypeDescriptor? d = lookup_descriptor (detail);
    return (d != null)? d.display_name : _("Other");
  }

  public void update_details (AbstractFieldDetails details, TreeIter iter) {
    var old_parameters = details.parameters;
    details.parameters = new HashMultiMap<string, string> ();
    bool has_pref = false;
    foreach (var val in old_parameters["type"]) {
      if (val.ascii_casecmp ("PREF") == 0) {
        has_pref = true;
        break;
      }
    }
    foreach (var param in old_parameters.get_keys()) {
      if (param != "type" && param != X_GOOGLE_LABEL)
        foreach (var val in old_parameters[param])
          details.parameters[param] = val;
    }

    TypeDescriptor descriptor;
    string display_name;
    store.get (iter, 0, out display_name, 1, out descriptor);

    assert (display_name != null); // Not separator

    if (descriptor == null) { // A custom label
      details.parameters["type"] = "OTHER";
      details.parameters[X_GOOGLE_LABEL] = display_name;
    } else {
      if (descriptor == other_dummy) {
        details.parameters["type"] = "OTHER";
      } else {
        VcardTypeMapping? vcard_mapping = descriptor.vcard_mapping;
        for (int j = 0; j < MAX_TYPES && vcard_mapping.types[j] != null; j++)
          details.parameters["type"] = vcard_mapping.types[j];
      }
    }

    if (has_pref)
      details.parameters["type"] = "PREF";
  }

  private static TypeSet _general;
  private const VcardTypeMapping[] general_data = {
    // List most specific first, always in upper case
    { N_("Home"), { "HOME" } },
    { N_("Work"), { "WORK" } }
  };
  public static TypeSet general {
    get {
      string[] standard = {
        "Work", "Home"
      };

      if (_general == null) {
        _general = new TypeSet ();
        for (int i = 0; i < general_data.length; i++)
          _general.add_vcard_mapping (general_data[i]);
        _general.add_vcard_mapping_done (standard);
      }

      return _general;
    }
  }

  private static TypeSet _email;
  private const VcardTypeMapping[] email_data = {
    // List most specific first, always in upper case
    { N_("Personal"),    { "PERSONAL" } },
    { N_("Home"),        { "HOME" } },
    { N_("Work"),        { "WORK" } }
  };
  public static TypeSet email {
    get {
      string[] standard = {
        "Personal", "Home", "Work"
      };

      if (_email == null) {
        _email = new TypeSet ();
        for (int i = 0; i < email_data.length; i++)
          _email.add_vcard_mapping (email_data[i]);
        _email.add_vcard_mapping_done (standard);
      }

      return _email;
    }
  }

  private static TypeSet _phone;
  public static TypeSet phone {
    get {
      const VcardTypeMapping[] data = {
        // List most specific first, always in upper case
        { N_("Assistant"),  { "X-EVOLUTION-ASSISTANT" } },
        { N_("Work"),       { "WORK", "VOICE" } },
        { N_("Work Fax"),   { "WORK", "FAX" } },
        { N_("Callback"),   { "X-EVOLUTION-CALLBACK" } },
        { N_("Car"),        { "CAR" } },
        { N_("Company"),    { "X-EVOLUTION-COMPANY" } },
        { N_("Home"),       { "HOME", "VOICE" } },
        { N_("Home Fax"),   { "HOME", "FAX" } },
        { N_("ISDN"),       { "ISDN" } },
        { N_("Mobile"),     { "CELL" } },
        { N_("Other"),      { "VOICE" } },
        { N_("Fax"),        { "FAX" } },
        { N_("Pager"),      { "PAGER" } },
        { N_("Radio"),      { "X-EVOLUTION-RADIO" } },
        { N_("Telex"),      { "X-EVOLUTION-TELEX" } },
        /* To translators: TTY is Teletypewriter */
        { N_("TTY"),        { "X-EVOLUTION-TTYTDD" } }
      };

      // Make sure these strings are the same as the above
      string[] standard = {
        "Mobile", "Work", "Home"
      };

      if (_phone == null) {
        _phone = new TypeSet ();
        for (int i = 0; i < data.length; i++)
          _phone.add_vcard_mapping (data[i]);
        for (int i = 0; i < general_data.length; i++)
          _phone.add_vcard_mapping (general_data[i]);
        _phone.add_vcard_mapping_done (standard);
      }

      return _phone;
    }
  }
}
