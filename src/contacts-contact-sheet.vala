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
using Folks;
using Gee;

/**
 * The contact sheet displays the actual information of a contact.
 *
 * (Note: to edit a contact, use the {@link ContactEditor} instead.
 */
public class Contacts.ContactSheet : ContactForm {

  public ContactSheet (Contact contact, Store store) {
    this.contact = contact;
    this.store = store;

    this.contact.individual.notify.connect (update);
    this.contact.individual.personas_changed.connect (update);
    this.store.quiescent.connect (update);

    update ();
  }

  private void update () {
    clear_previous_details ();

    this.avatar_widget = new Avatar (PROFILE_SIZE, this.contact);
    attach_avatar_widget (this.avatar_widget);

    create_name_label ();

    foreach (var p in this.contact.individual.personas) {
      foreach (var prop_name in ContactForm.SORTED_PROPERTIES) {
        var prop = add_row_for_property (p, prop_name);
        if (prop != null)
          add_property (prop);
      }
    }

    show_all ();
  }

  private void clear_previous_details () {
    if (this.avatar_widget != null)
      this.avatar_widget.destroy ();
    this.avatar_widget = null;

    if (this.name_widget != null)
      this.name_widget.destroy ();
    this.name_widget = null;

    this.props.remove_all ();
  }

  private void update_name_widget () {
    var name = Markup.printf_escaped ("<span font='16'>%s</span>",
                                      this.contact.individual.display_name);
    ((Label) this.name_widget).set_markup (name);
  }

  private void create_name_label () {
    var name_label = new Label ("");
    name_label.ellipsize = Pango.EllipsizeMode.END;
    name_label.xalign = 0f;
    name_label.selectable = true;
    set_name_widget (name_label);

    update_name_widget ();
    this.contact.individual.notify["display-name"].connect ((obj, spec) => {
        update_name_widget ();
      });
  }

  private PersonaProperty? add_row_for_property (Persona persona, string property_name) {
    switch (property_name) {
      case "email-addresses":
        if (EmailsProperty.should_show (persona))
          return new EmailsProperty (persona);
        break;
      case "phone-numbers":
        if (PhoneNrsProperty.should_show (persona))
          return new PhoneNrsProperty (persona);
        break;
      case "urls":
        if (UrlsProperty.should_show (persona))
          return new UrlsProperty (persona);
        break;
      case "nickname":
        if (NicknameProperty.should_show (persona))
          return new NicknameProperty (persona);
        break;
      case "birthday":
        if (BirthdayProperty.should_show (persona))
          return new BirthdayProperty (persona);
        break;
      case "notes":
        if (NotesProperty.should_show (persona))
          return new NotesProperty (persona);
        break;
      case "postal-addresses":
        if (PostalAddressesProperty.should_show (persona))
          return new PostalAddressesProperty (persona);
        break;
      default:
        debug ("Unsupported property: %s", property_name);
        break;
    }

    return null;
  }
}
