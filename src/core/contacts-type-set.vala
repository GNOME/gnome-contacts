/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A TypeSet contains all the possible types of a property. For example, a
 * phone number can be both for a personal phone, a work phone or even a fax
 * machine.
 */
public class Contacts.TypeSet : Object, GLib.ListModel  {

  /** Returns the category of typeset (mostly used for debugging). */
  public string category { get; construct set; }

  // Dummy TypeDescriptor to mark the "Other..." store entry
  private TypeDescriptor other_dummy = new TypeDescriptor.other ();

  // List of VcardTypeMapping. This makes sure of keeping the correct order
  private GenericArray<VcardTypeMapping?> vcard_type_mappings
      = new GenericArray<VcardTypeMapping?> ();

  private GenericArray<TypeDescriptor> descriptors = new GenericArray<TypeDescriptor> ();

  /**
   * Creates a TypeSet for the given category, e.g. "phones" (used for debugging)
   */
  private TypeSet (string? category) {
    Object (category: category);
  }

  /**
   * Adds the TypeDescriptor to the {@link TypeSet}'s store.
   * @param descriptor The TypeDescription to be added
   */
  private void add_descriptor (TypeDescriptor descriptor) {
    debug ("%s: Adding type %s to store", this.category, descriptor.to_string ());
    this.descriptors.add (descriptor);
    this.items_changed (this.descriptors.length - 1, 0, 1);
  }

  /**
   * Returns the TypeDescriptor for the given display name in the
   * {@link TypeSet}'s store, if any.
   *
   * @param display_name The translated display name
   * @return The appropriate TypeDescriptor or null if no match was found.
   */
  public unowned TypeDescriptor? lookup_by_display_name (string display_name,
                                                         out uint position) {
    for (int i = 0; i < this.descriptors.length; i++) {
      unowned var type_descr = this.descriptors[i];

      if (display_name.ascii_casecmp (type_descr.display_name) != 0)
        continue;
      if (display_name.ascii_casecmp (type_descr.name) != 0)
        continue;

      position = i;
      return type_descr;
    }

    // Nothing was found
    position = 0;
    return null;
  }

  private void add_vcard_mapping (VcardTypeMapping vcard_mapping) {
    uint position;
    var descriptor = lookup_by_display_name (vcard_mapping.name, out position);
    if (descriptor == null) {
      descriptor = new TypeDescriptor.vcard (vcard_mapping.name, vcard_mapping.types);
      debug ("%s: Adding VCard type %s to store", this.category, descriptor.to_string ());
      this.add_descriptor (descriptor);
    }

    this.vcard_type_mappings.add (vcard_mapping);
  }

  /**
   * Tries to find the TypeDescriptor matching the given custom label, or null if none.
   */
  public TypeDescriptor? lookup_by_custom_label (string label,
                                                 out uint position) {
    // Check in the current display names
    unowned var descriptor = lookup_by_display_name (label, out position);
    if (descriptor != null)
      return descriptor;

    // Try again, but use the vcard types too
    descriptor = lookup_by_vcard_type (label, out position);
    return descriptor;
  }

  private TypeDescriptor create_descriptor_for_custom_label (string label) {
    var new_descriptor = new TypeDescriptor.custom (label);
    debug ("%s: Adding custom type %s to store",
           this.category, new_descriptor.to_string ());
    this.add_descriptor (new_descriptor);
    return new_descriptor;
  }

  /**
   * Returns the TypeDescriptor which corresponds the best to the given vcard type.
   * @param str A VCard-like type, such as "HOME" or "CELL".
   */
  public unowned TypeDescriptor? lookup_by_vcard_type (string str,
                                                       out uint position) {
    foreach (unowned var mapping in this.vcard_type_mappings) {
      if (mapping.contains (str))
        return lookup_by_display_name (mapping.name, out position);
    }

    position = 0;
    return null;
  }

  /**
   * Looks up the TypeDescriptor for the given parameters. If the descriptor
   * is not found, it will be created and returned, so this never returns null.
   */
  public TypeDescriptor lookup_by_parameters (Gee.MultiMap<string, string> parameters,
                                              out uint position = null) {
    var google_label = parameters[TypeDescriptor.X_GOOGLE_LABEL];
    if (!google_label.is_empty) {
      var label = google_label.to_array ()[0];
      var descriptor = lookup_by_custom_label (label, out position);
      // Still didn't find it => create it
      if (descriptor == null)
        descriptor = create_descriptor_for_custom_label (label);
      return descriptor;
    }

    var types = parameters["type"];
    if (types == null || types.is_empty) {
      debug ("No types given in the AbstractFieldDetails");
      return this.other_dummy;
    }

    foreach (unowned var mapping in this.vcard_type_mappings) {
      if (mapping.matches (types))
        return lookup_by_display_name (mapping.name, out position);
    }

    return this.other_dummy;
  }

  public GLib.Type get_item_type () {
    return typeof (TypeDescriptor);
  }

  public uint get_n_items () {
    return this.descriptors.length;
  }

  public GLib.Object? get_item (uint i) {
    if (i > this.descriptors.length)
      return null;

    return this.descriptors[i];
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

        _general.add_descriptor (general.other_dummy);
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
        _email.add_descriptor (_email.other_dummy);
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
        _phone.add_descriptor (_phone.other_dummy);
      }

      return _phone;
    }
  }
}
