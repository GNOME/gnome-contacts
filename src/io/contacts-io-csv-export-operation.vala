/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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
 * An implementation of {@link Contacts.Io.Exporter} that serializes a contact
 * to CSV (Comma-Separated Values).
 *
 * Its default values are based on the output of Google Contacts' CSV output.
 */
public class Contacts.Io.CsvExportOperation : ExportOperation {

  private List<FieldSerializer> field_serializers = new List<FieldSerializer> ();

  /** What separator should be used */
  public string separator { get; construct set; default = ","; }

  /** Whether to write a line with the header */
  public bool header { get; construct set; default = true; }

  private string _description;
  public override string description { owned get { return this._description; } }

  construct {
    this._description = ngettext ("Exported %d contact",
                                  "Exported %d contacts",
                                  individuals.size).printf (individuals.size);

    // Initialize the field serializers
    this.field_serializers.append (new NameSerializer ());
  }

  public CsvExportOperation (Gee.List<Individual> individuals,
                             GLib.OutputStream output) {
    Object(individuals: individuals, output: output);
  }

  public override async void execute () throws GLib.Error {
    if (this.header)
      write_header ();

    foreach (var individual in this.individuals) {
      foreach (var persona in individual.personas) {
        foreach (unowned var field_serializer in this.field_serializers) {
          var fields = field_serializer.serialize_persona ();
          foreach (unowned var field in fields) {
            if (header.data.length > 0)
              header.append (this.separator);
            header.append (label);
          }
        }
      }
    }
  }

  public abstract class FieldSerializer : Object {

    /** How this field / these fields are called in the header */
    public abstract string[] header_labels { owned get; }

    public abstract string[] serialize_persona (Persona persona);
  }

  public class NameSerializer : FieldSerializer {

    public override string[] header_labels {
      owned get {
        return { "Name" };
      }
    }

    public override string[] serialize_persona (Persona persona) {
      string[] fields = {};
      if (persona is NameDetails) {
        unowned var details = (NameDetails) persona;

        fields += details.full_name;
      } else {
        fields += "";
      }

      return fields;
    }
  }

  private void write_header () throws GLib.Error {
    var header = new StringBuilder();

    foreach (unowned var field_serializer in this.field_serializers) {
      foreach (unowned var label in field_serializer.header_labels) {
        if (header.data.length > 0)
          header.append (this.separator);
        header.append (label);
      }
    }

    write_record (header.str);
  }

#if 0
  private void write_persona (Persona persona) {
    write_name_fields (vcard, persona);

    if (persona is BirthdayDetails)
      write_birthday_field (vcard, (BirthdayDetails) persona);
    if (persona is EmailDetails)
      write_email_fields (vcard, (EmailDetails) persona);
    if (persona is FavouriteDetails)
      write_favourite_field (vcard, (FavouriteDetails) persona);
    if (persona is NoteDetails)
      write_note_fields (vcard, (NoteDetails) persona);
    if (persona is PhoneDetails)
      write_phone_fields (vcard, (PhoneDetails) persona);
    if (persona is PostalAddressDetails)
      write_postal_address_fields (vcard, (PostalAddressDetails) persona);
    if (persona is RoleDetails)
      write_role_fields (vcard, (RoleDetails) persona);
    if (persona is UrlDetails)
      write_url_fields (vcard, (UrlDetails) persona);

    // The following don't really map properly atm, or are just not worth it.
    // If we still want/need them later, we can add them still of course
/*
    if (persona is AvatarDetails)
      write_avatar_field (vcard, (AvatarDetails) persona);
    if (persona is AliasDetails)
      write_alias_field (vcard, (AliasDetails) persona);
    if (persona is ExtendedInfo)
      vcard_set_extended_info (vcard, (ExtendedInfo) persona);
    if (persona is GenderDetails)
      write_gender_field (vcard, (GenderDetails) persona);
    if (persona is GroupDetails)
      write_group_field (vcard, (GroupDetails) persona);
    if (persona is ImDetails)
      write_im_field (vcard, (ImDetails) persona);
    if (persona is InteractionDetails)
      write_interaction_field (vcard, (InteractionDetails) persona);
    if (persona is LocalIdDetails)
      write_localid_field (vcard, (LocalIdDetails) persona);
    if (persona is LocationDetails)
      write_location_field (vcard, (LocationDetails) persona);
    if (persona is PresenceDetails)
      write_presence_field (vcard, (PresenceDetails) persona);
    if (persona is WebServiceDetails)
      write_webservice_field (vcard, (WebServiceDetails) persona);
*/

    vcard.to_string (this.vcard_format);
  }

  private void write_avatar_field (E.VCard vcard,
                                         AvatarDetails details) {
    // FIXME: not sure how we want to do this in such as way that doesn't break
    // inside a sandbox or without embedding the data directly (which will blow
    // up the file size)
  }

  private void write_birthday_field (E.VCard vcard,
                                           BirthdayDetails details) {
    if (details.birthday == null)
      return;

    var attr = new E.VCardAttribute (null, E.EVC_BDAY);
    attr.add_param_with_value (new E.VCardAttributeParam (E.EVC_VALUE), "DATE");
    vcard.add_attribute_with_value ((owned) attr, details.birthday.format ("%F"));
  }

  private void write_email_field (E.VCard vcard,
                                        EmailDetails details) {
    foreach (var email_field in details.email_addresses) {
      if (email_field.value == "")
        continue;

      var attr = new E.VCardAttribute (null, E.EVC_EMAIL);
      vcard.add_attribute_with_value (attr, email_field.value);
      add_parameters_for_field_details (attr, email_field);
    }
  }

  private void write_favourite_field (E.VCard vcard,
                                            FavouriteDetails details) {
    if (details.is_favourite) {
      // See Edsf.Persona
      var attr = new E.VCardAttribute (null, "X-FOLKS-FAVOURITE");
      vcard.add_attribute_with_value ((owned) attr, "true");
    }
  }

  private void write_name_fields (Persona persona) {
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

  private void write_note_field (E.VCard vcard,
                                       NoteDetails details) {
    foreach (var note_field in details.notes) {
      if (note_field.value == "")
        continue;

      var attr = new E.VCardAttribute (null, E.EVC_NOTE);
      add_parameters_for_field_details (attr, note_field);
      vcard.add_attribute_with_value ((owned) attr, note_field.value);
    }
  }

  private void write_phone_field (E.VCard vcard,
                                        PhoneDetails details) {
    foreach (var phone_field in details.phone_numbers) {
      if (phone_field.value == "")
        continue;

      var attr = new E.VCardAttribute (null, E.EVC_TEL);
      add_parameters_for_field_details (attr, phone_field);
      vcard.add_attribute_with_value ((owned) attr, phone_field.value);
    }
  }

  private void write_postal_address_field (E.VCard vcard,
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

  private void write_role_field (E.VCard vcard,
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

  private void write_url_field (E.VCard vcard,
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
#endif

  // Helper to check if the given field should be escaped in the CSV result
  private bool should_escape (string field) {
    return field.contains (this.separator) || field.contains ("\n");
  }

  private void write_record (string line) throws GLib.Error {
    size_t written;
    this.output.write_all (line.data, out written);
    this.output.write_all ("\n".data, out written);
  }
}
