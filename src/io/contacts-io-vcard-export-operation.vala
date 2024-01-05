/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * An implementation of {@link Contacts.Io.Exporter} that serializes a contact
 * to the VCard format.
 *
 * Internally, it uses the E.VCard class to implement most of the logic.
 */
public class Contacts.Io.VCardExportOperation : ExportOperation {

  // We _could_ parameterize this with our own enum, but there's no need for
  // that at the moment.
  private E.VCardFormat vcard_format = E.VCardFormat.@30;

  // This should always be on false, except for debugging/troubleshooting
  // purposes. It forces E-D-S personas to use our manual serialization instead
  // of just returning their own internal E.VCard representation
  private bool avoid_eds = false;

  private string _description;
  public override string description { owned get { return this._description; } }

  public VCardExportOperation (Gee.List<Individual> individuals,
                               GLib.OutputStream output) {
    Object(individuals: individuals, output: output);

    this._description = ngettext ("Exported %d contact",
                                  "Exported %d contacts",
                                  individuals.size).printf (individuals.size);
  }

  public override async void execute () throws GLib.Error {
    foreach (var individual in this.individuals) {
      // FIXME: should we aggregate personas somehow?

      foreach (var persona in individual.personas) {
        string vcard_str = persona_to_vcard (persona);
        size_t written;
        this.output.write_all (vcard_str.data, out written);
        this.output.write_all ("\r\n\r\n".data, out written);
      }
    }
  }

  private string persona_to_vcard (Persona persona) {
    // Take a shortcut in case we have an Edsf.Persona, since
    // that's an E.VCard already
    if (persona is Edsf.Persona && !avoid_eds) {
      unowned var contact = ((Edsf.Persona) persona).contact;
      return contact.to_string (this.vcard_format);
    }

    var vcard = new E.VCard ();

    if (persona is AvatarDetails)
      vcard_set_avatar_details (vcard, (AvatarDetails) persona);
    if (persona is BirthdayDetails)
      vcard_set_birthday_details (vcard, (BirthdayDetails) persona);
    if (persona is EmailDetails)
      vcard_set_email_details (vcard, (EmailDetails) persona);
    if (persona is FavouriteDetails)
      vcard_set_favourite_details (vcard, (FavouriteDetails) persona);
    if (persona is NameDetails)
      vcard_set_name_details (vcard, (NameDetails) persona);
    if (persona is NoteDetails)
      vcard_set_note_details (vcard, (NoteDetails) persona);
    if (persona is PhoneDetails)
      vcard_set_phone_details (vcard, (PhoneDetails) persona);
    if (persona is PostalAddressDetails)
      vcard_set_postal_address_details (vcard, (PostalAddressDetails) persona);
    if (persona is RoleDetails)
      vcard_set_role_details (vcard, (RoleDetails) persona);
    if (persona is UrlDetails)
      vcard_set_url_details (vcard, (UrlDetails) persona);

    // The following don't really map properly atm, or are just not worth it.
    // If we still want/need them later, we can add them still of course
/*
    if (persona is AliasDetails)
      vcard_set_alias_details (vcard, (AliasDetails) persona);
    if (persona is ExtendedInfo)
      vcard_set_extended_info (vcard, (ExtendedInfo) persona);
    if (persona is GenderDetails)
      vcard_set_gender_details (vcard, (GenderDetails) persona);
    if (persona is GroupDetails)
      vcard_set_group_details (vcard, (GroupDetails) persona);
    if (persona is ImDetails)
      vcard_set_im_details (vcard, (ImDetails) persona);
    if (persona is InteractionDetails)
      vcard_set_interaction_details (vcard, (InteractionDetails) persona);
    if (persona is LocalIdDetails)
      vcard_set_localid_details (vcard, (LocalIdDetails) persona);
    if (persona is LocationDetails)
      vcard_set_location_details (vcard, (LocationDetails) persona);
    if (persona is PresenceDetails)
      vcard_set_presence_details (vcard, (PresenceDetails) persona);
    if (persona is WebServiceDetails)
      vcard_set_webservice_details (vcard, (WebServiceDetails) persona);
*/

    return vcard.to_string (this.vcard_format);
  }

  private void vcard_set_avatar_details (E.VCard vcard,
                                         AvatarDetails details) {
    // FIXME: not sure how we want to do this in such as way that doesn't break
    // inside a sandbox or without embedding the data directly (which will blow
    // up the file size)
  }

  private void vcard_set_birthday_details (E.VCard vcard,
                                           BirthdayDetails details) {
    if (details.birthday == null)
      return;

    var attr = new E.VCardAttribute (null, E.EVC_BDAY);
    attr.add_param_with_value (new E.VCardAttributeParam (E.EVC_VALUE), "DATE");
    vcard.add_attribute_with_value ((owned) attr, details.birthday.format ("%F"));
  }

  private void vcard_set_email_details (E.VCard vcard,
                                        EmailDetails details) {
    foreach (var email_field in details.email_addresses) {
      if (email_field.value == "")
        continue;

      var attr = new E.VCardAttribute (null, E.EVC_EMAIL);
      vcard.add_attribute_with_value (attr, email_field.value);
      add_parameters_for_field_details (attr, email_field);
    }
  }

  private void vcard_set_favourite_details (E.VCard vcard,
                                            FavouriteDetails details) {
    if (details.is_favourite) {
      // See Edsf.Persona
      var attr = new E.VCardAttribute (null, "X-FOLKS-FAVOURITE");
      vcard.add_attribute_with_value ((owned) attr, "true");
    }
  }

  private void vcard_set_name_details (E.VCard vcard,
                                       NameDetails details) {
    if (details.full_name != "") {
      vcard.add_attribute_with_value (new E.VCardAttribute (null, E.EVC_FN),
                                      details.full_name);
    }

    if (details.structured_name != null) {
      var attr = new E.VCardAttribute (null, E.EVC_N);

      attr.add_value (details.structured_name.family_name);
      attr.add_value (details.structured_name.given_name);
      attr.add_value (details.structured_name.additional_names);
      attr.add_value (details.structured_name.prefixes);
      attr.add_value (details.structured_name.suffixes);

      vcard.add_attribute ((owned) attr);
    }

    if (details.nickname != "") {
      vcard.add_attribute_with_value (new E.VCardAttribute (null, E.EVC_NICKNAME),
                                      details.nickname);
    }
  }

  private void vcard_set_note_details (E.VCard vcard,
                                       NoteDetails details) {
    foreach (var note_field in details.notes) {
      if (note_field.value == "")
        continue;

      var attr = new E.VCardAttribute (null, E.EVC_NOTE);
      add_parameters_for_field_details (attr, note_field);
      vcard.add_attribute_with_value ((owned) attr, note_field.value);
    }
  }

  private void vcard_set_phone_details (E.VCard vcard,
                                        PhoneDetails details) {
    foreach (var phone_field in details.phone_numbers) {
      if (phone_field.value == "")
        continue;

      var attr = new E.VCardAttribute (null, E.EVC_TEL);
      add_parameters_for_field_details (attr, phone_field);
      vcard.add_attribute_with_value ((owned) attr, phone_field.value);
    }
  }

  private void vcard_set_postal_address_details (E.VCard vcard,
                                                 PostalAddressDetails details) {
    foreach (var postal_field in details.postal_addresses) {
      unowned var addr = postal_field.value;
      if (addr.is_empty ())
        continue;

      var attr = new E.VCardAttribute (null, E.EVC_ADR);
      add_parameters_for_field_details (attr, postal_field);

      attr.add_value (addr.po_box);
      attr.add_value (addr.extension);
      attr.add_value (addr.street);
      attr.add_value (addr.locality);
      attr.add_value (addr.region);
      attr.add_value (addr.postal_code);
      attr.add_value (addr.country);

      vcard.add_attribute ((owned) attr);
    }
  }

  private void vcard_set_role_details (E.VCard vcard,
                                       RoleDetails details) {
    foreach (var role_field in details.roles) {
      if (role_field.value.title != "") {
        vcard.add_attribute_with_value (new E.VCardAttribute (null, E.EVC_TITLE),
                                        role_field.value.title);
      }
      if (role_field.value.organisation_name != "") {
        vcard.add_attribute_with_value (new E.VCardAttribute (null, E.EVC_ORG),
                                        role_field.value.organisation_name);
      }
    }
  }

  private void vcard_set_url_details (E.VCard vcard,
                                      UrlDetails details) {
    foreach (var url_field in details.urls) {
      if (url_field.value == "")
        continue;

      var attr = new E.VCardAttribute (null, E.EVC_URL);
      add_parameters_for_field_details (attr, url_field);
      vcard.add_attribute_with_value ((owned) attr, url_field.value);
    }
  }

  // Helper to get common parameters (e.g. type)
  private void add_parameters_for_field_details (E.VCardAttribute attr,
                                                 AbstractFieldDetails field) {
    Gee.Collection<string>? param_values = null;

    param_values = field.get_parameter_values (AbstractFieldDetails.PARAM_TYPE);
    if (param_values != null && !param_values.is_empty) {
      var param = new E.VCardAttributeParam (E.EVC_TYPE);
      foreach (var typestr in param_values)
        param.add_value (typestr.up ());
      attr.add_param ((owned) param);
    }
  }
}
