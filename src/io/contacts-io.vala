/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
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

using Folks;

/**
 * Everything in the Io namespace deals with importing and exporting contacts,
 * both internally (between Contacts and a subprocess, using {@link GLib.Variant}
 * serialization) and externally (VCard, CSV, ...).
 */
namespace Contacts.Io {

  /**
   * Serializes a list of {@link GLib.HashTable}s as returned by a
   * {@link Contacts.Io.Parser} into a {@link GLib.Variant} so it can be sent
   * from one process to another.
   */
  public GLib.Variant serialize_to_gvariant (HashTable<string, Value?>[] details_list) {
    var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));

    foreach (unowned var details in details_list) {
      builder.add_value (serialize_to_gvariant_single (details));
    }

    return builder.end ();
  }

  /**
   * Serializes a single {@link GLib.HashTable} into a {@link GLib.Variant}.
   */
  public GLib.Variant serialize_to_gvariant_single (HashTable<string, Value?> details) {
    var dict = new GLib.VariantDict ();

    var iter = HashTableIter<string, Value?> (details);
    unowned string prop;
    unowned Value? val;
    while (iter.next (out prop, out val)) {

      if (prop == Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME)) {
        serialize_full_name (dict, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME)) {
        serialize_structured_name (dict, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.NICKNAME)) {
        serialize_nickname (dict, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY)) {
        serialize_birthday (dict, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES)) {
        serialize_addresses (dict, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS)) {
        serialize_phone_nrs (dict, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES)) {
        serialize_emails (dict, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.NOTES)) {
        serialize_notes (dict, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.URLS)) {
        serialize_urls (dict, prop, val);
      } else {
        warning ("Couldn't serialize unknown property '%s'", prop);
      }
    }

    return dict.end ();
  }

  /**
   * Deserializes the {@link GLib.Variant} back into a {@link GLib.HashTable}.
   */
  public HashTable<string, Value?>[] deserialize_gvariant (GLib.Variant variant)
      requires (variant.get_type ().equal (new VariantType ("aa{sv}"))) {

    var result = new GenericArray<HashTable<string, Value?>> ();

    var iter = variant.iterator ();
    GLib.Variant element;
    while (iter.next ("@a{sv}", out element)) {
      result.add (deserialize_gvariant_single (element));
    }

    return result.steal ();
  }

  /**
   * Deserializes the {@link GLib.Variant} back into a {@link GLib.HashTable}.
   */
  public HashTable<string, Value?> deserialize_gvariant_single (GLib.Variant variant) {
    return_val_if_fail (variant.get_type ().equal (VariantType.VARDICT), null);

    var details = new HashTable<string, Value?> (GLib.str_hash, GLib.str_equal);

    var iter = variant.iterator ();
    string prop;
    GLib.Variant val;
    while (iter.next ("{sv}", out prop, out val)) {

      if (prop == Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME)) {
        deserialize_full_name (details, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME)) {
        deserialize_structured_name (details, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.NICKNAME)) {
        deserialize_nickname (details, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY)) {
        deserialize_birthday (details, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES)) {
        deserialize_addresses (details, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS)) {
        deserialize_phone_nrs (details, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES)) {
        deserialize_emails (details, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.NOTES)) {
        deserialize_notes (details, prop, val);
      } else if (prop == Folks.PersonaStore.detail_key (PersonaDetail.URLS)) {
        deserialize_urls (details, prop, val);
      } else {
        warning ("Couldn't serialize unknown property '%s'", prop);
      }
    }

    return details;
  }

  //
  // FULL NAME
  // -----------------------------------
  private const string FULL_NAME_TYPE = "s";

  private bool serialize_full_name (GLib.VariantDict dict, string prop, Value? val) {
    return_val_if_fail (val.type () == typeof (string), false);

    unowned string full_name = val as string;
    return_val_if_fail (full_name != null, false);

    dict.insert (prop, FULL_NAME_TYPE, full_name);

    return true;
  }

  private bool deserialize_full_name (HashTable<string, Value?> details, string prop, Variant variant) {
    return_val_if_fail (variant.get_type ().equal (VariantType.STRING), false);

    unowned string full_name = variant.get_string ();
    return_val_if_fail (full_name != null, false);

    details.insert (prop, full_name);

    return true;
  }

  //
  // NICKNAME
  // -----------------------------------
  private const string STRUCTURED_NAME_TYPE = "(sssss)";

  private bool serialize_structured_name (GLib.VariantDict dict, string prop, Value? val) {
    return_val_if_fail (val.type () == typeof (StructuredName), false);

    unowned var name = val as StructuredName;
    return_val_if_fail (name != null, false);

    dict.insert (prop, STRUCTURED_NAME_TYPE,
                 name.family_name, name.given_name, name.additional_names,
                 name.prefixes, name.suffixes);

    return true;
  }

  private bool deserialize_structured_name (HashTable<string, Value?> details, string prop, Variant variant) {
    return_val_if_fail (variant.get_type ().equal (new VariantType (STRUCTURED_NAME_TYPE)), false);

    string family_name, given_name, additional_names, prefixes, suffixes;
    variant.get (STRUCTURED_NAME_TYPE,
                 out family_name,
                 out given_name,
                 out additional_names,
                 out prefixes,
                 out suffixes);

    var structured_name = new StructuredName (family_name, given_name, additional_names,
                                              prefixes, suffixes);
    details.insert (prop, structured_name);

    return true;
  }

  //
  // NICKNAME
  // -----------------------------------
  private const string NICKNAME_TYPE = "s";

  private bool serialize_nickname (GLib.VariantDict dict, string prop, Value? val) {
    return_val_if_fail (val.type () == typeof (string), false);

    unowned string nickname = val as string;
    return_val_if_fail (nickname != null, false);

    dict.insert (prop, NICKNAME_TYPE, nickname);

    return true;
  }

  private bool deserialize_nickname (HashTable<string, Value?> details, string prop, Variant variant) {
    return_val_if_fail (variant.get_type ().equal (VariantType.STRING), false);

    unowned string nickname = variant.get_string ();
    return_val_if_fail (nickname != null, false);

    details.insert (prop, nickname);

    return true;
  }

  //
  // BIRTHDAY
  // -----------------------------------
  private const string BIRTHDAY_TYPE = "(iii)"; // Year-Month-Day

  private bool serialize_birthday (GLib.VariantDict dict, string prop, Value? val) {
    return_val_if_fail (val.type () == typeof (DateTime), false);

    unowned var bd = val as DateTime;
    return_val_if_fail (bd != null, false);

    int year, month, day;
    bd.get_ymd (out year, out month, out day);
    dict.insert (prop, BIRTHDAY_TYPE, year, month, day);

    return true;
  }

  private bool deserialize_birthday (HashTable<string, Value?> details, string prop, Variant variant) {
    return_val_if_fail (variant.get_type ().equal (new VariantType (BIRTHDAY_TYPE)), false);

    int year, month, day;
    variant.get (BIRTHDAY_TYPE, out year, out month, out day);

    var bd = new DateTime.utc (year, month, day, 0, 0, 0.0);

    details.insert (prop, bd);

    return true;
  }

  //
  // POSTAL ADDRESSES
  // -----------------------------------
  private const string ADDRESS_TYPE = "(sssssssv)";
  private const string ADDRESSES_TYPE = "a" + ADDRESS_TYPE;

  private bool serialize_addresses (GLib.VariantDict dict, string prop, Value? val) {
    return_val_if_fail (val.type () == typeof (Gee.Set), false);

    // Get the list of field details
    unowned var afds = val as Gee.Set<PostalAddressFieldDetails>;
    return_val_if_fail (afds != null, false);

    // Turn the set of field details into an array Variant
    var builder = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
    foreach (var afd in afds) {
      unowned PostalAddress addr = afd.value;

      builder.add (ADDRESS_TYPE,
          addr.po_box,
          addr.extension,
          addr.street,
          addr.locality,
          addr.region,
          addr.postal_code,
          addr.country,
          serialize_parameters (afd));
    }

    dict.insert_value (prop, builder.end ());

    return true;
  }

  private bool deserialize_addresses (HashTable<string, Value?> details, string prop, Variant variant) {
    return_val_if_fail (variant.get_type ().equal (new VariantType ("a" + ADDRESS_TYPE)), false);

    var afds = new Gee.HashSet<PostalAddressFieldDetails> ();

    // Turn the array variant into a set of field details
    var iter = variant.iterator ();

    string po_box, extension, street, locality, region, postal_code, country;
    GLib.Variant parameters;
    while (iter.next (ADDRESS_TYPE,
                      out po_box,
                      out extension,
                      out street,
                      out locality,
                      out region,
                      out postal_code,
                      out country,
                      out parameters)) {
      if (po_box == "" && extension == "" && street == "" && locality == ""
          && region == "" && postal_code == "" && country == "") {
        warning ("Got empty postal address");
        continue;
      }

      var addr = new PostalAddress (po_box, extension, street, locality, region,
                                    postal_code, country, "", null);

      var afd = new PostalAddressFieldDetails (addr);
      deserialize_parameters (parameters, afd);

      afds.add (afd);
    }

    details.insert (prop, afds);

    return true;
  }

  //
  // PHONE NUMBERS
  // -----------------------------------
  private bool serialize_phone_nrs (GLib.VariantDict dict, string prop, Value? val) {
    return serialize_afd_strings (dict, prop, val);
  }

  private bool deserialize_phone_nrs (HashTable<string, Value?> details, string prop, Variant variant) {
    return deserialize_afd_str (details, prop, variant,
                                (str) => { return new PhoneFieldDetails (str); });
  }

  //
  // EMAILS
  // -----------------------------------
  private bool serialize_emails (GLib.VariantDict dict, string prop, Value? val) {
    return serialize_afd_strings (dict, prop, val);
  }

  private bool deserialize_emails (HashTable<string, Value?> details, string prop, Variant variant) {
    return deserialize_afd_str (details, prop, variant,
                                (str) => { return new EmailFieldDetails (str); });
  }

  //
  // NOTES
  // -----------------------------------
  private bool serialize_notes (GLib.VariantDict dict, string prop, Value? val) {
    return serialize_afd_strings (dict, prop, val);
  }

  private bool deserialize_notes (HashTable<string, Value?> details, string prop, Variant variant) {
    return deserialize_afd_str (details, prop, variant,
                                (str) => { return new NoteFieldDetails (str); });
  }

  //
  // URLS
  // -----------------------------------
  private bool serialize_urls (GLib.VariantDict dict, string prop, Value? val) {
    return serialize_afd_strings (dict, prop, val);
  }

  private bool deserialize_urls (HashTable<string, Value?> details, string prop, Variant variant) {
    return deserialize_afd_str (details, prop, variant,
                                (str) => { return new UrlFieldDetails (str); });
  }

  //
  // HELPER: AbstractFielDdetail<string>
  // -----------------------------------
  private const string AFD_STRING_TYPE = "(sv)";

  private bool serialize_afd_strings (GLib.VariantDict dict, string prop, Value? val) {
    return_val_if_fail (val.type () == typeof (Gee.Set), false);

    // Get the list of field details
    unowned var afds = val as Gee.Set<AbstractFieldDetails<string>>;
    return_val_if_fail (afds != null, false);

    // Turn the set of field details into an array Variant
    var builder = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
    foreach (var afd in afds) {
      builder.add (AFD_STRING_TYPE, afd.value, serialize_parameters (afd));
    }

    dict.insert_value (prop, builder.end ());

    return true;
  }

  // In an ideal world, we wouldn't need this delegate and we could just use
  // GLib.Object.new(), but this is Vala and generics, so we find ourselves in
  // a big mess here
  delegate AbstractFieldDetails<string> CreateAbstractFieldStrFunc(string value);

  private bool deserialize_afd_str (HashTable<string, Value?> details,
                                    string prop,
                                    Variant variant,
                                    CreateAbstractFieldStrFunc create_afd_func) {
    return_val_if_fail (variant.get_type ().equal (new VariantType ("a" + AFD_STRING_TYPE)), false);

    var afds = new Gee.HashSet<AbstractFieldDetails> ();

    // Turn the array variant into a set of field details
    var iter = variant.iterator ();
    string str;
    GLib.Variant parameters;
    while (iter.next (AFD_STRING_TYPE, out str, out parameters)) {
      AbstractFieldDetails afd = create_afd_func (str);
      deserialize_parameters (parameters, afd);

      afds.add (afd);
    }

    details.insert (prop, afds);

    return true;
  }

  //
  // HELPER: Parameters
  // -----------------------------------
  // We can't use a vardict here, since one key can map to multiple values.
  private const string PARAMS_TYPE = "a(ss)";

  private Variant serialize_parameters (AbstractFieldDetails details) {

    if (details.parameters == null || details.parameters.size == 0) {
      return new GLib.Variant (PARAMS_TYPE, null); // Empty array
    }

    var builder = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
    var iter = details.parameters.map_iterator ();
    while (iter.next ()) {
      string param_name = iter.get_key ();
      string param_value = iter.get_value ();

      builder.add ("(ss)", param_name, param_value);
    }

    return builder.end ();
  }

  private void deserialize_parameters (Variant parameters, AbstractFieldDetails details) {
    return_if_fail (parameters.get_type ().is_array ());

    var iter = parameters.iterator ();
    string param_name, param_value;
    while (iter.next ("(ss)", out param_name, out param_value)) {
      if (param_name == AbstractFieldDetails.PARAM_TYPE)
        details.add_parameter (param_name, param_value.down ());
      else
        details.add_parameter (param_name, param_value);
    }
  }
}
