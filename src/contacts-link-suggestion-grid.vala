/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * This program is distributed in the hope that it will be useful,
 *
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
 * The LinkSuggestionGrid is show at the bottom of the ContactPane.
 * It offers the user the sugugestion of linking the currently shown contact
 * and another (hopefully) similar contact.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-link-suggestion-grid.ui")]
public class Contacts.LinkSuggestionGrid : Grid {
  private const int AVATAR_SIZE = 54;

  [GtkChild]
  private Gtk.Label description_label;
  [GtkChild]
  private Gtk.Label extra_info_label;
  [GtkChild]
  private Gtk.Button accept_button;
  [GtkChild]
  private Gtk.Button reject_button;

  public signal void suggestion_accepted ();
  public signal void suggestion_rejected ();

  public LinkSuggestionGrid (Contact contact) {
    get_style_context ().add_class ("contacts-suggestion");

    var image_frame = new Avatar (AVATAR_SIZE);
    image_frame.hexpand = false;
    image_frame.margin = 12;
    contact.keep_widget_uptodate (image_frame,  (w) => {
        (w as Avatar).set_image.begin (contact.individual, contact);
      });
    image_frame.show ();
    attach (image_frame, 0, 0, 1, 2);

    this.description_label.xalign = 0; // FIXME: hack to make it actually align left.
    this.description_label.label = contact.is_main?
          _("Is this the same person as %s from %s?").printf (contact.individual.display_name, contact.format_persona_stores ())
        : _("Is this the same person as %s?").printf (contact.individual.display_name);

    var extra_info = find_extra_description (contact);
    if (extra_info != null) {
      this.extra_info_label.show ();
      this.extra_info_label.label = extra_info;
    }

    this.reject_button.clicked.connect ( () => suggestion_rejected ());
    this.accept_button.clicked.connect ( () => suggestion_accepted ());
  }

  private string? find_extra_description (Contact contact) {
    // First try an email address
    var emails = contact.individual.email_addresses;
    if (!emails.is_empty)
      return Utils.get_first<EmailFieldDetails> (emails).value;

    // Maybe a website? Works well with e.g. social media profiles
    var urls = contact.individual.urls;
    if (!urls.is_empty)
      return Utils.get_first<UrlFieldDetails> (urls).value;

    // Try a phone number
    var phones = contact.individual.phone_numbers;
    if (!phones.is_empty)
      return Utils.get_first<PhoneFieldDetails> (phones).value;

    // A postal address maybe?
    var addresses = contact.individual.postal_addresses;
    if (!addresses.is_empty)
      return Utils.get_first<PostalAddressFieldDetails> (addresses).value.to_string ();

    // We're out of ideas now.
    return null;
  }
}
