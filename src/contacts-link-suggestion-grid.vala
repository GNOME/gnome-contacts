/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * The LinkSuggestionGrid is show at the bottom of the ContactPane.
 * It offers the user the sugugestion of linking the currently shown contact
 * and another (hopefully) similar contact.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-link-suggestion-grid.ui")]
public class Contacts.LinkSuggestionGrid : Gtk.Box {

  private const int AVATAR_SIZE = 54;

  [GtkChild]
  private unowned Gtk.Label description_label;
  [GtkChild]
  private unowned Gtk.Label extra_info_label;
  [GtkChild]
  private unowned Gtk.Button accept_button;
  [GtkChild]
  private unowned Gtk.Button reject_button;
  [GtkChild]
  private unowned Adw.Bin avatar_bin;

  public signal void suggestion_accepted ();
  public signal void suggestion_rejected ();

  public LinkSuggestionGrid (Individual individual) {
    var image_frame = new Avatar (AVATAR_SIZE, individual);
    avatar_bin.set_child (image_frame);

    this.description_label.label = Contacts.Utils.has_main_persona (individual) ?
      _("Is this the same person as %s from %s?")
       .printf (individual.display_name,
                Contacts.Utils.format_persona_stores (individual))
      : _("Is this the same person as %s?").printf (individual.display_name);

    var extra_info = find_extra_description (individual);
    if (extra_info != null) {
      this.extra_info_label.label = extra_info;
    }

    this.reject_button.clicked.connect ( () => suggestion_rejected ());
    this.accept_button.clicked.connect ( () => suggestion_accepted ());
  }

  private string? find_extra_description (Individual individual) {
    // First try an email address
    unowned var emails = individual.email_addresses;
    if (!emails.is_empty)
      return Utils.get_first<EmailFieldDetails> (emails).value;

    // Maybe a website? Works well with e.g. social media profiles
    unowned var urls = individual.urls;
    if (!urls.is_empty)
      return Utils.get_first<UrlFieldDetails> (urls).value;

    // Try a phone number
    unowned var phones = individual.phone_numbers;
    if (!phones.is_empty)
      return Utils.get_first<PhoneFieldDetails> (phones).value;

    // A postal address maybe?
    unowned var addresses = individual.postal_addresses;
    if (!addresses.is_empty)
      return Utils.get_first<PostalAddressFieldDetails> (addresses).value.to_string ();

    // We're out of ideas now.
    return null;
  }
}
