/*
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A {@link Contacts.Io.Parser} that specifically deals with parsing VCard
 */
public class Contacts.Io.VCardParser : Contacts.Io.Parser {

  public VCardParser () {
  }

  public override Contact[] parse (InputStream input) throws GLib.Error {
    // Read the whole input into a string.
    // We can probably do better, but that takes a bit of extra work
    var memory_stream = new MemoryOutputStream.resizable ();
    memory_stream.splice (input, 0, null);
    memory_stream.write ("\0".data);
    memory_stream.close ();
    var input_str = (string) memory_stream.get_data ();

    var result = new GenericArray<Contact> ();

    // Parse the input stream into a set of vcards
    int begin_index = input_str.index_of ("BEGIN:VCARD");
    while (begin_index != -1) {
      // Find the END:VCARD attribute to know the substring
      int end_vcard_index = input_str.index_of ("END:VCARD", begin_index + 1);
      int end_index = end_vcard_index + "END:VCARD".length;
      var vcard_str = input_str[begin_index:end_index];

      // Parse this VCard
      var vcard = new E.VCard.from_string (vcard_str);
      // FIXME: we should have some kind of error check here

      unowned var vcard_attrs = vcard.get_attributes ();
      debug ("Got %u attributes in this vcard", vcard_attrs.length ());

      var contact = new Contact.empty ();
      // For the structure of this switch-case, see RFC 6350
      foreach (unowned E.VCardAttribute attr in vcard_attrs) {
        switch (attr.get_name ()) {
          // Identification Properties
          case E.EVC_FN:
            handle_fn (contact, attr);
            break;
          case E.EVC_N:
            handle_n (contact, attr);
            break;
          case E.EVC_NICKNAME:
            handle_nickname (contact, attr);
            break;
/* FIXME
          case E.EVC_PHOTO:
            handle_photo (contact, attr);
            break;
*/
          case E.EVC_BDAY:
            handle_bday (contact, attr);
            break;
          // Delivery Addressing Properties
          case E.EVC_ADR:
            handle_adr (contact, attr);
            break;
          // Communications Properties
          case E.EVC_TEL:
            handle_tel (contact, attr);
            break;
          case E.EVC_EMAIL:
            handle_email (contact, attr);
            break;
          // Organizational Properties
          case E.EVC_TITLE:
            handle_title (contact, attr);
            break;
          case E.EVC_ORG:
            handle_org (contact, attr);
            break;
          // Explanatory Properties
          case E.EVC_NOTE:
            handle_note (contact, attr);
            break;
          case E.EVC_URL:
            handle_url (contact, attr);
            break;

          default:
            debug ("Unknown property name '%s'", attr.get_name ());
            break;
        }
      }

      result.add (contact);

      begin_index = input_str.index_of ("BEGIN:VCARD", end_index);
    }

    return result.steal ();
  }

  // Handles the "FN" (Full Name) attribute
  private void handle_fn (Contact contact, E.VCardAttribute attr) {
    var full_name = attr.get_value ();
    debug ("Got FN '%s'", full_name);

    // Note that the full-name chunk is a bit special since it's usually
    // added as a chunk, even for empty contacts
    var chunk = contact.get_most_relevant_chunk ("full-name", true) ??
                contact.create_chunk ("full-name", null);
    unowned var fn_chunk = (FullNameChunk) chunk;
    fn_chunk.full_name = full_name;
  }

  // Handles the "N" (structured Name) attribute
  private void handle_n (Contact contact, E.VCardAttribute attr) {
    unowned var values = attr.get_values ();

    // From the VCard spec:
    // The structured property value corresponds, in sequence, to the Family
    // Names (also known as surnames), Given Names, Additional Names, Honorific
    // Prefixes, and Honorific Suffixes.
    var sn_chunk = (StructuredNameChunk) contact.create_chunk ("structured-name", null);
    sn_chunk.structured_name.family_name = values.nth_data (0) ?? "";
    sn_chunk.structured_name.given_name = values.nth_data (1) ?? "";
    sn_chunk.structured_name.additional_names = values.nth_data (2) ?? "";
    sn_chunk.structured_name.prefixes = values.nth_data (3) ?? "";
    sn_chunk.structured_name.suffixes = values.nth_data (4) ?? "";
  }

  private void handle_nickname (Contact contact, E.VCardAttribute attr) {
    var nickname = attr.get_value ();
    debug ("Got nickname '%s'", nickname);

    var nick_chunk = (NicknameChunk) contact.create_chunk ("nickname", null);
    nick_chunk.nickname = nickname;
  }

  // Handles the "BDAY" (birthday) attribute
  private void handle_bday (Contact contact, E.VCardAttribute attr) {
    var bday = attr.get_value ();
    var e_date = E.ContactDate.from_string (bday);
    var datetime = new DateTime.utc ((int) e_date.year,
                                     (int) e_date.month,
                                     (int) e_date.day,
                                     0, 0, 0.0);

    var bd_chunk = (BirthdayChunk) contact.create_chunk ("birthday", null);
    bd_chunk.birthday = datetime;
  }

  private void handle_email (Contact contact, E.VCardAttribute attr) {
    var email = attr.get_value ();
    if (email == null || email == "")
      return;

    var child = add_chunk_child_for_property (contact, "email-addresses");
    ((EmailAddress) child).raw_address = email;
    add_params (child, attr);
  }

  private void handle_tel (Contact contact, E.VCardAttribute attr) {
    var phone_nr = attr.get_value ();
    if (phone_nr == null || phone_nr == "")
      return;

    var child = add_chunk_child_for_property (contact, "phone-numbers");
    ((Phone) child).raw_number = phone_nr;
    add_params (child, attr);
  }

  // Handles the ADR (postal address) attributes
  private void handle_adr (Contact contact, E.VCardAttribute attr) {
    unowned var values = attr.get_values ();

    var child = add_chunk_child_for_property (contact, "postal-addresses");
    unowned var address = ((Address) child).address;

    // From the VCard spec:
    // ADR-value = ADR-component-pobox ";" ADR-component-ext ";"
    //             ADR-component-street ";" ADR-component-locality ";"
    //             ADR-component-region ";" ADR-component-code ";"
    //             ADR-component-country
    address.po_box = values.nth_data (0) ?? "";
    address.extension = values.nth_data (1) ?? "";
    address.street = values.nth_data (2) ?? "";
    address.locality = values.nth_data (3) ?? "";
    address.region = values.nth_data (4) ?? "";
    address.postal_code = values.nth_data (5) ?? "";
    address.country = values.nth_data (6) ?? "";

    add_params (child, attr);
  }

  private void handle_url (Contact contact, E.VCardAttribute attr) {
    var url = attr.get_value ();
    if (url == null || url == "")
      return;

    var child = add_chunk_child_for_property (contact, "urls");
    ((Contacts.Url) child).raw_url = url;
    add_params (child, attr);
  }

  private void handle_title (Contact contact, E.VCardAttribute attr) {
    var title = attr.get_value ();
    if (title == null || title == "")
      return;

    // NOTE: we have handle this specially, since properties like
    // TITLE, ORG etc can occur multiple times but there's no way to link them
    // to each other. Just add a OrgRole once and ignore the others for now
    var chunk = (BinChunk) contact.get_most_relevant_chunk ("roles", true);
    if (chunk != null) {
      var orgrole = (Contacts.OrgRole) chunk.get_item (0);
      if (orgrole.role.title == "")
        orgrole.role.title = title;
      return;
    }

    var child = add_chunk_child_for_property (contact, "roles");
    ((Contacts.OrgRole) child).role.title = title;
    add_params (child, attr);
  }

  private void handle_org (Contact contact, E.VCardAttribute attr) {
    unowned var values = attr.get_values ();
    unowned var org = values.data;
    if (org == null || org == "")
      return;

    // NOTE: we have handle this specially, since properties like
    // TITLE, ORG etc can occur multiple times but there's no way to link them
    // to each other. Just add a OrgRole once and ignore the others for now
    var chunk = (BinChunk) contact.get_most_relevant_chunk ("roles", true);
    if (chunk != null) {
      var orgrole = (Contacts.OrgRole) chunk.get_item (0);
      if (orgrole.role.organisation_name == "")
        orgrole.role.organisation_name = org;
      return;
    }

    var child = add_chunk_child_for_property (contact, "roles");
    ((Contacts.OrgRole) child).role.organisation_name = org;
    add_params (child, attr);
  }

  private void handle_note (Contact contact, E.VCardAttribute attr) {
    var note = attr.get_value ();
    if (note == null || note == "")
      return;

    var child = add_chunk_child_for_property (contact, "notes");
    ((Contacts.Note) child).text = note;
    add_params (child, attr);
  }

  // Helper method for inserting aggregated properties
  private BinChunkChild add_chunk_child_for_property (Contact contact,
                                                      string property_name) {
    var chunk = (BinChunk) contact.get_most_relevant_chunk (property_name, true);
    if (chunk == null)
      chunk = (BinChunk) contact.create_chunk (property_name, null);

    // BinChunk guarantees there will always be an empty child, so return the
    // first one we can find
    for (uint i = 0; i < chunk.get_n_items (); i++) {
      var child = (BinChunkChild) chunk.get_item (i);
      if (child.is_empty)
        return child;
    }

    return_val_if_reached (null);
  }

  // Helper method to get VCard parameters into a BinChunkChild
  // Will take care of setting the correct "type"
  private void add_params (BinChunkChild chunk_child, E.VCardAttribute attr) {
    foreach (unowned E.VCardAttributeParam param in attr.get_params ()) {
      string param_name = param.get_name ().down ();
      foreach (unowned string param_value in param.get_values ()) {
        if (param_name == "type")
          chunk_child.add_parameter (param_name, param_value.down ());
        else
          chunk_child.add_parameter (param_name, param_value);
      }
    }
  }
}
