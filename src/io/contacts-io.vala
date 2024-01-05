/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * Everything in the Io namespace deals with importing and exporting contacts,
 * both internally (between Contacts and a subprocess, using {@link GLib.Variant}
 * serialization) and externally (VCard, CSV, ...).
 */
namespace Contacts.Io {

  /**
   * Serializes a list of {@link Contact}s as returned by a
   * {@link Contacts.Io.Parser} into a {@link GLib.Variant} so it can be sent
   * from one process to another.
   */
  public GLib.Variant serialize_to_gvariant (Contacts.Contact[]? contacts) {
    var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));

    foreach (unowned var contact in contacts) {
      var variant = contact.to_gvariant ();
      if (variant.n_children () == 0)
        continue;
      builder.add_value (variant);
    }

    return builder.end ();
  }

  /**
   * Deserializes the {@link GLib.Variant} back into a list of
   * {@link Contacts.Contact}s.
   */
  public Contacts.Contact[] deserialize_gvariant (Variant variant)
      requires (variant.get_type ().equal (new VariantType ("aa{sv}"))) {

    var result = new GenericArray<Contacts.Contact> ();

    var iter = variant.iterator ();
    GLib.Variant element;
    while (iter.next ("@a{sv}", out element)) {
      var contact = new Contact.for_gvariant (element);
      result.add (contact);
    }

    return result.steal ();
  }
}
