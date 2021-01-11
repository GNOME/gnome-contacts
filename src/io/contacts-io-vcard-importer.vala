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
 * a {@link Contacts.Io.Importer} that specifically deals with importing
 * VCard files/strings.
 */
public class Contacts.Io.VCardImporter : Contacts.Io.Importer {

  public VCardImporter () {
  }

  /**
   * Takes the given VCard string and tries to parse it into a
   * {@link GLib.HashTable}, which can then be used for methods like
   * {@link Folks.PersonaStore.add_persona_from_details}.
   */
  public override HashTable<string, Value?> import_string (string vcard_str) {
    var details = new HashTable<string, Value?> (GLib.str_hash, GLib.str_equal);
    var vcard = new E.VCard.from_string (vcard_str);

    unowned var vcard_attrs = vcard.get_attributes ();
    message ("Got %u attributes in this vcard", vcard_attrs.length ());

    foreach (unowned E.VCardAttribute attr in vcard_attrs) {
      switch (attr.get_name ()) {
        // Identification Properties
        case E.EVC_FN:
          handle_fn (details, attr);
          break;
        case E.EVC_N:
          handle_n (details, attr);
          break;
        case E.EVC_NICKNAME:
          handle_nickname (details, attr);
          break;
/*
        case E.EVC_PHOTO:
          handle_photo (details, attr);
          break;
*/
        case E.EVC_BDAY:
          handle_bday (details, attr);
          break;
        // Delivery Addressing Properties
        case E.EVC_ADR:
          handle_adr (details, attr);
          break;
        // Communications Properties
        case E.EVC_TEL:
          handle_tel (details, attr);
          break;
        case E.EVC_EMAIL:
          handle_email (details, attr);
          break;
        // Explanatory Properties
        case E.EVC_NOTE:
          handle_note (details, attr);
          break;
        case E.EVC_URL:
          handle_url (details, attr);
          break;

        default:
          debug ("Unknown property name '%s'", attr.get_name ());
          break;
      }
    }

    return details;
  }

  // Handles the "FN" (Full Name) attribute
  private void handle_fn (HashTable<string, Value?> details,
                          E.VCardAttribute attr) {
    var full_name = attr.get_value ();
    message ("Got FN '%s'", full_name);

    Value? fn_v = Value (typeof (string));
    fn_v.set_string (full_name);
    details.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
                    (owned) fn_v);
  }

  // Handles the "N" (structured Name) attribute
  private void handle_n (HashTable<string, Value?> details,
                         E.VCardAttribute attr) {
    unowned var values = attr.get_values ();

    // From the VCard spec:
    // The structured property value corresponds, in sequence, to the Family
    // Names (also known as surnames), Given Names, Additional Names, Honorific
    // Prefixes, and Honorific Suffixes.
    unowned var family_name = values.nth_data (0) ?? "";
    unowned var given_name = values.nth_data (1) ?? "";
    unowned var additional_names = values.nth_data (2) ?? "";
    unowned var prefixes = values.nth_data (3) ?? "";
    unowned var suffixes = values.nth_data (4) ?? "";

    var structured_name = new StructuredName (family_name, given_name,
                                              additional_names,
                                              prefixes, suffixes);
    Value? n_v = Value (typeof (StructuredName));
    n_v.take_object ((owned) structured_name);
    details.insert (Folks.PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME),
                    (owned) n_v);
  }

  private void handle_nickname (HashTable<string, Value?> details,
                                E.VCardAttribute attr) {
    var nickname = attr.get_value ();
    message ("Got nickname '%s'", nickname);

    Value? nick_v = Value (typeof (string));
    nick_v.set_string (nickname);
    details.insert (Folks.PersonaStore.detail_key (PersonaDetail.NICKNAME),
                    (owned) nick_v);
  }

  // Handles the "BDAY" (birthday) attribute
  private void handle_bday (HashTable<string, Value?> details,
                            E.VCardAttribute attr) {
    // Get the attribute valuec
    var bday = attr.get_value ();

    // Parse it using the logic in E.ContactDate
    var e_date = E.ContactDate.from_string (bday);

    // Turn it into a GLib.DateTime
    var datetime = new DateTime.utc ((int) e_date.year,
                                     (int) e_date.month,
                                     (int) e_date.day,
                                     0, 0, 0.0);

    // Insert it into the hashtable as a GLib.Value
    Value? bday_val = Value (typeof (DateTime));
    bday_val.take_boxed ((owned) datetime);
    details.insert (Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY),
                    (owned) bday_val);
  }

  private void handle_email (HashTable<string, Value?> details,
                             E.VCardAttribute attr) {
    var email = attr.get_value ();
    if (email == null || email == "")
      return;

    var email_fd = new EmailFieldDetails (email);
    add_params (email_fd, attr);
    insert_field_details<EmailFieldDetails> (details, PersonaDetail.EMAIL_ADDRESSES,
                                             email_fd,
                                             AbstractFieldDetails<string>.hash_static,
                                             AbstractFieldDetails<string>.equal_static);
  }

  private void handle_tel (HashTable<string, Value?> details,
                           E.VCardAttribute attr) {
    var phone_nr = attr.get_value ();
    if (phone_nr == null || phone_nr == "")
      return;

    var phone_fd = new PhoneFieldDetails (phone_nr);
    add_params (phone_fd, attr);
    insert_field_details<PhoneFieldDetails> (details, PersonaDetail.PHONE_NUMBERS,
                                             phone_fd,
                                             AbstractFieldDetails<string>.hash_static,
                                             AbstractFieldDetails<string>.equal_static);
  }

  // Handles the ADR (postal address) attributes
  private void handle_adr (HashTable<string, Value?> details,
                           E.VCardAttribute attr) {
    unowned var values = attr.get_values ();

    // From the VCard spec:
    // ADR-value = ADR-component-pobox ";" ADR-component-ext ";"
    //             ADR-component-street ";" ADR-component-locality ";"
    //             ADR-component-region ";" ADR-component-code ";"
    //             ADR-component-country
    unowned var po_box = values.nth_data (0) ?? "";
    unowned var extension = values.nth_data (1) ?? "";
    unowned var street = values.nth_data (2) ?? "";
    unowned var locality = values.nth_data (3) ?? "";
    unowned var region = values.nth_data (4) ?? "";
    unowned var postal_code = values.nth_data (5) ?? "";
    unowned var country = values.nth_data (6) ?? "";

    var addr = new PostalAddress (po_box, extension, street, locality, region,
                                  postal_code, country, "", null);
    var addr_fd = new PostalAddressFieldDetails ((owned) addr);
    add_params (addr_fd, attr);

    insert_field_details<PostalAddressFieldDetails> (details,
                                                     PersonaDetail.POSTAL_ADDRESSES,
                                                     addr_fd,
                                                     AbstractFieldDetails<PostalAddress>.hash_static,
                                                     AbstractFieldDetails<PostalAddress>.equal_static);
  }

  private void handle_url (HashTable<string, Value?> details,
                           E.VCardAttribute attr) {
    var url = attr.get_value ();
    if (url == null || url == "")
      return;

    var url_fd = new UrlFieldDetails (url);
    add_params (url_fd, attr);
    insert_field_details<UrlFieldDetails> (details, PersonaDetail.URLS,
                                           url_fd,
                                           AbstractFieldDetails<string>.hash_static,
                                           AbstractFieldDetails<string>.equal_static);
  }

  private void handle_note (HashTable<string, Value?> details,
                            E.VCardAttribute attr) {
    var note = attr.get_value ();
    if (note == null || note == "")
      return;

    var note_fd = new NoteFieldDetails (note);
    add_params (note_fd, attr);
    insert_field_details<NoteFieldDetails> (details, PersonaDetail.NOTES,
                                            note_fd,
                                            AbstractFieldDetails<string>.hash_static,
                                            AbstractFieldDetails<string>.equal_static);

  }

  // Helper method for inserting aggregated properties
  private bool insert_field_details<T> (HashTable<string, Value?> details,
                                        PersonaDetail key,
                                        T field_details,
                                        owned Gee.HashDataFunc<T>? hash_func,
                                        owned Gee.EqualDataFunc<T>? equal_func) {

    // Get the existing set, or create a new one and add it
    unowned var old_val = details.lookup (Folks.PersonaStore.detail_key (key));
    if (old_val != null) {
      unowned var values = old_val as Gee.HashSet<T>;
      return values.add (field_details);
    }

    var values = new Gee.HashSet<T> ((owned) hash_func, (owned) equal_func);
    Value? new_val = Value (typeof (Gee.Set));
    new_val.set_object (values);
    details.insert (Folks.PersonaStore.detail_key (key), (owned) new_val);

    return values.add (field_details);
  }

  // Helper method to get VCard parameters into an AbstractFieldDetails object.
  // Will take care of setting the correct "type"
  private void add_params (AbstractFieldDetails details, E.VCardAttribute attr) {
    foreach (unowned E.VCardAttributeParam param in attr.get_params ()) {
      string param_name = param.get_name ().down ();
      foreach (unowned string param_value in param.get_values ()) {
        if (param_name == AbstractFieldDetails.PARAM_TYPE)
          details.add_parameter (param_name, param_value.down ());
        else
          details.add_parameter (param_name, param_value);
      }
    }
  }
}
