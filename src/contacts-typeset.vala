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

/**
 * A TypeSet contains all the possible types of a property. For example, a
 * phone number can be both for a personal phone, a work phone or even a fax
 * machine.
 */
public class Contacts.TypeSet : Object  {

  /** Returns the category of typeset (mostly used for debugging). */
  public string category { get; construct set; }

  // Dummy TypeDescriptor to mark the "Other..." store entry
  private TypeDescriptor other_dummy = new TypeDescriptor.other ();

  // List of VcardTypeMapping. This makes sure of keeping the correct order
  private Gee.List<VcardTypeMapping?> vcard_type_mappings
      = new Gee.ArrayList<VcardTypeMapping?> ();

  // Contains 2 columns:
  // 1. The type's display name (or null for a separator)
  // 2. The TypeDescriptor
  public Gtk.ListStore store { get; private set; }

  /**
   * Creates a TypeSet for the given category, e.g. "phones" (used for debugging)
   */
  private TypeSet (string? category) {
    Object (category: category);

    this.store = new Gtk.ListStore (2, typeof (unowned string?), typeof (TypeDescriptor));
  }

  /**
   * Returns the TreeIter which corresponds to the type of the given
   * AbstractFieldDetails.
   */
  public void get_iter_for_field_details (AbstractFieldDetails detail, out TreeIter iter) {
    // Note that we shouldn't have null here, but it's there just to be sure.
    var d = lookup_descriptor_for_field_details (detail);
    iter = d.iter;
  }

  /**
   * Returns the TreeIter which corresponds the best to the given vcard type.
   * @param type: A VCard-like type, such as "HOME" or "CELL".
   */
  public void get_iter_for_vcard_type (string type, out TreeIter iter) {
    unowned TypeDescriptor? d = lookup_descriptor_by_vcard_type (type);
    iter = (d != null)? d.iter : this.other_dummy.iter;
  }

  /**
   * Returns the TreeIter which corresponds the best to the given custom label.
   */
  public void get_iter_for_custom_label (string label, out TreeIter iter) {
    var descr = get_descriptor_for_custom_label (label);
    if (descr == null)
      descr = create_descriptor_for_custom_label (label);
    iter = descr.iter;
  }

  /**
   * Returns the display name for the type of the given AbstractFieldDetails.
   */
  public string format_type (AbstractFieldDetails detail) {
    var d = lookup_descriptor_for_field_details (detail);
    return d.display_name;
  }

  /**
   * Adds the TypeDescriptor to the {@link Typeset}'s store.
   * @param descriptor: The TypeDescription to be added
   */
  private void add_descriptor_to_store (TypeDescriptor descriptor) {
    debug ("%s: Adding type %s to store", this.category, descriptor.to_string ());

    if (descriptor.is_custom ())
      this.store.insert_before (out descriptor.iter, null);
    else
      this.store.append (out descriptor.iter);

    store.set (descriptor.iter, 0, descriptor.display_name, 1, descriptor);
  }

  /**
   * Returns the TypeDescriptor for the given display name in the
   * {@link Typeset}'s store, if any.
   *
   * @param display_name: The translated display name
   * @return: The appropriate TypeDescriptor or null if no match was found.
   */
  public unowned TypeDescriptor? lookup_descriptor_in_store (string display_name) {
    TreeIter iter;

    // Make sure we handle an empty store
    if (!this.store.get_iter_first (out iter))
      return null;

    do {
      unowned TypeDescriptor? type_descr;
      this.store.get (iter, 1, out type_descr);

      if (display_name.ascii_casecmp (type_descr.display_name) == 0)
        return type_descr;
      if (display_name.ascii_casecmp (type_descr.name) == 0)
        return type_descr;
    } while (this.store.iter_next (ref iter));

    // Nothing was found
    return null;
  }

  private void add_vcard_mapping (VcardTypeMapping vcard_mapping) {
    TypeDescriptor? descriptor = lookup_descriptor_in_store (vcard_mapping.name);
    if (descriptor == null) {
      descriptor = new TypeDescriptor.vcard (vcard_mapping.name, vcard_mapping.types);
      add_descriptor_to_store (descriptor);
    }

    this.vcard_type_mappings.add (vcard_mapping);
  }

  // Refers to the type of the detail, i.e. "Other" instead of "Personal" or "Work"
  private void add_type_other () {
    store.append (out other_dummy.iter);
    store.set (other_dummy.iter, 0, other_dummy.display_name, 1, other_dummy);
  }

  /**
   * Tries to find the TypeDescriptor matching the given custom label, or null if none.
   */
  public unowned TypeDescriptor? get_descriptor_for_custom_label (string label) {
    // Check in the current display names
    unowned TypeDescriptor? descriptor = lookup_descriptor_in_store (label);
    if (descriptor != null)
      return descriptor;

    // Try again, but use the vcard types too
    descriptor = lookup_descriptor_by_vcard_type (label);
    return descriptor;
  }

  private TypeDescriptor create_descriptor_for_custom_label (string label) {
    var new_descriptor = new TypeDescriptor.custom (label);
    add_descriptor_to_store (new_descriptor);
    return new_descriptor;
  }

  /**
   * Returns the TypeDescriptor which corresponds the best to the given vcard type.
   * @param str: A VCard-like type, such as "HOME" or "CELL".
   */
  private unowned TypeDescriptor? lookup_descriptor_by_vcard_type (string str) {
    foreach (VcardTypeMapping? mapping in this.vcard_type_mappings) {
      if (mapping.contains (str))
        return lookup_descriptor_in_store (mapping.name);
    }

    return null;
  }

  public TypeDescriptor lookup_descriptor_for_field_details (AbstractFieldDetails detail) {
    if (detail.parameters.contains (TypeDescriptor.X_GOOGLE_LABEL)) {
      var label = Utils.get_first<string> (detail.parameters[TypeDescriptor.X_GOOGLE_LABEL]);
      var descriptor = get_descriptor_for_custom_label (label);
      // Still didn't find it => create it
      if (descriptor == null)
        descriptor = create_descriptor_for_custom_label (label);
      return descriptor;
    }

    var types = detail.get_parameter_values ("type");
    if (types == null || types.is_empty) {
      warning ("No types given in the AbstractFieldDetails");
      return this.other_dummy;
    }

    foreach (VcardTypeMapping? d in this.vcard_type_mappings) {
      if (d.matches (types))
        return lookup_descriptor_in_store (d.name);
    }

    return this.other_dummy;
  }


  private static TypeSet _general;
  private const VcardTypeMapping[] general_data = {
    // List most specific first, always in upper case
    { N_("Home"), { "HOME" } },
    { N_("Work"), { "WORK" } }
  };
  public static TypeSet general {
    get {
      if (_general == null) {
        _general = new TypeSet ("General");
        for (int i = 0; i < general_data.length; i++)
          _general.add_vcard_mapping (general_data[i]);
        _general.add_type_other ();
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
      if (_email == null) {
        _email = new TypeSet ("Emails");
        for (int i = 0; i < email_data.length; i++)
          _email.add_vcard_mapping (email_data[i]);
        _email.add_type_other ();
      }

      return _email;
    }
  }

  private static TypeSet _phone;
  private const VcardTypeMapping[] phone_data = {
    // List most specific first, always in upper case
    { N_("Assistant"),  { "X-EVOLUTION-ASSISTANT" } },
    { N_("Work"),       { "WORK", "VOICE" } },
    { N_("Work Fax"),   { "WORK", "FAX" } },
    { N_("Work"),       { "WORK" } },
    { N_("Callback"),   { "X-EVOLUTION-CALLBACK" } },
    { N_("Car"),        { "CAR" } },
    { N_("Company"),    { "X-EVOLUTION-COMPANY" } },
    { N_("Home"),       { "HOME", "VOICE" } },
    { N_("Home Fax"),   { "HOME", "FAX" } },
    { N_("Home"),       { "HOME" } },
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
  public static TypeSet phone {
    get {

      if (_phone == null) {
        _phone = new TypeSet ("Phones");
        for (int i = 0; i < phone_data.length; i++)
          _phone.add_vcard_mapping (phone_data[i]);
        _phone.add_type_other ();
      }

      return _phone;
    }
  }
}
