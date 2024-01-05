/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * The TypeComboRow is a widget that fills itself with the types of a certain
 * category (using {@link Contacts.TypeSet}). For example, it allows the user
 * to choose between "Personal", "Home" and "Work" for email addresses,
 * together with all the custom labels it has encountered since then.
 */
public class Contacts.TypeComboRow : Adw.ComboRow  {

  public TypeDescriptor selected_descriptor {
    get { return (TypeDescriptor) this.selected_item; }
  }

  public TypeSet type_set {
    get { return (TypeSet) this.model; }
  }

  /**
   * Creates a TypeComboRow for the given TypeSet.
   */
  public TypeComboRow (TypeSet type_set) {
    Object (
      model: type_set,
      expression: new Gtk.PropertyExpression (typeof (TypeDescriptor), null, "display-name")
    );
  }

  /**
   * Sets the value to the type that best matches the given vcard type
   * (for example "HOME" or "WORK").
   */
  public void set_selected_from_vcard_type (string type) {
    uint position = 0;
    this.type_set.lookup_by_vcard_type (type, out position);
    this.selected = position;
  }

  /**
   * Sets the value to the type that best matches the given vcard type
   * (for example "HOME" or "WORK").
   */
  public void set_selected_from_parameters (Gee.MultiMap<string, string> parameters) {
    uint position = 0;
    this.type_set.lookup_by_parameters (parameters, out position);
    this.selected = position;
  }
}
