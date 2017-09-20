/*
 * Copyright (C) 2017 Niels De Graef <nielsdegraef@gmail.com>
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
using Gee;
using Gtk;

/**
 * A Factory for DetailEditors.
 */
public class Contacts.Editor.DetailsEditorFactory : Object {

  /**
   * Creates a DetailEditor for a specific property, given a persona.
   * @return The newly created editor, or null if no editor was created.
   */
  public DetailsEditor? create_details_editor (Persona? p, string prop_name, bool allow_empty = false) {
    switch (prop_name) {
      case "birthday":
        return create_birthday_editor (p, allow_empty);
      case "email-addresses":
        return create_emails_editor (p, allow_empty);
      case "nickname":
        return create_nickname_editor (p, allow_empty);
      case "notes":
        return create_notes_editor (p, allow_empty);
      case "phone-numbers":
        return create_phones_editor (p, allow_empty);
      case "postal-addresses":
        return create_addresses_editor (p, allow_empty);
      case "urls":
        return create_urls_editor (p, allow_empty);
      default:
        debug ("Unsupported property name \"%s\"", prop_name);
        return null;
    }
  }

  public BirthdayEditor? create_birthday_editor (Persona? p, bool allow_empty) {
    var birthday_details = p as BirthdayDetails;
    if (!allow_empty && (birthday_details == null || birthday_details.birthday == null))
      return null;
    return new BirthdayEditor (p as BirthdayDetails);
  }

  public EmailsEditor? create_emails_editor (Persona? p, bool allow_empty) {
    var email_details = p as EmailDetails;
    if (!allow_empty && (email_details == null || email_details.email_addresses.is_empty))
      return null;
    return new EmailsEditor (email_details);
  }

  public NicknameEditor? create_nickname_editor (Persona? p, bool allow_empty) {
    var name_details = p as NameDetails;
    if (!allow_empty && (name_details == null || name_details.nickname == null || name_details.nickname == ""))
      return null;
    return new NicknameEditor (name_details);
  }

  public NotesEditor? create_notes_editor (Persona? p, bool allow_empty) {
    var note_details = p as NoteDetails;
    if (!allow_empty && (note_details == null || note_details.notes.is_empty))
      return null;
    return new NotesEditor (note_details);
  }

  public PhonesEditor? create_phones_editor (Persona? p, bool allow_empty) {
    var phone_details = p as PhoneDetails;
    if (!allow_empty && (phone_details == null || phone_details.phone_numbers.is_empty))
      return null;
    return new PhonesEditor (phone_details);
  }

  public AddressesEditor? create_addresses_editor (Persona? p, bool allow_empty) {
    var address_details = p as PostalAddressDetails;
    if (!allow_empty && (address_details == null || address_details.postal_addresses.is_empty))
      return null;
    return new AddressesEditor (address_details);
  }

  public UrlsEditor? create_urls_editor (Persona? p, bool allow_empty) {
    var url_details = p as UrlDetails;
    if (!allow_empty && (url_details == null || url_details.urls.is_empty))
      return null;
    return new UrlsEditor (url_details);
  }
}
