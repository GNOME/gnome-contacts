/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * The contact sheet displays the actual information of a contact.
 *
 * (Note: to edit a contact, use the {@link ContactEditor} instead.
 */
public class Contacts.ContactSheet : Gtk.Widget {

  construct {
    var box_layout = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
    set_layout_manager (box_layout);

    this.add_css_class ("contacts-sheet");
  }

  public ContactSheet (Contact contact) {
    // Apply some filtering/sorting to the base model
    var filter = new ChunkFilter ();
    filter.persona_filter = new PersonaFilter ();
    var filtered = new Gtk.FilterListModel (contact, filter);
    var contact_model = new Gtk.SortListModel (filtered, new ChunkSorter ());

    var header = create_header (contact);
    header.set_parent (this);

    contact_model.items_changed.connect (on_model_items_changed);
    on_model_items_changed (contact_model, 0, 0, contact_model.get_n_items ());
  }

  public override void dispose () {
    unowned Gtk.Widget? child = null;
    while ((child = get_first_child ()) != null)
      child.unparent ();

    base.dispose ();
  }

  private void on_model_items_changed (GLib.ListModel model,
                                       uint position,
                                       uint removed,
                                       uint added) {
    // Get the widget where we'll have to append the item at "position". Note
    // that we need to take care of the header and the persona store titles
    unowned var child = get_first_child ();
    warn_if_fail (child != null); // Header is always available

    uint current_position = 0;
    while (current_position < position) {
      child = child.get_next_sibling ();
      // If this fails, we somehow have less widgets than items in our model
      warn_if_fail (child != null);

      // Ignore persona store labels
      if (child is Gtk.Label)
        continue;

      current_position++;
    }

    // First, remove the ones that were removed from the model too
    while (removed != 0) {
      unowned var to_remove = child.get_next_sibling ();
      warn_if_fail (to_remove != null); // if this happens we're out of sync
      to_remove.unparent ();
      removed--;
    }
    // It could be that we now ended up with a empty persona store label
    if (child is Gtk.Label) {
      child = child.get_prev_sibling ();
      child.get_next_sibling ().unparent ();
    }

    // Now, add the new ones
    for (uint i = position; i < position + added; i++) {
      var chunk = (Chunk) model.get_item (i);

      // Check if we need to add a persona store label
      if (i > 0 && chunk.persona != null && !(child is Gtk.Label)) {
        var prev = (Chunk?) model.get_item (i - 1);
        if (prev.persona != chunk.persona) {
          var label = create_persona_store_label (chunk.persona);
          label.insert_after (this, child);
          child = label;
        }
      }

      var new_child = create_widget_for_chunk (chunk);
      if (new_child != null) {
        new_child.insert_after (this, child);
        child = new_child;
      }
    }
  }

  private Gtk.Widget? create_widget_for_chunk (Chunk chunk) {
    switch (chunk.property_name) {
      case "avatar":
      case "full-name":
        return null; // Added separately in the header

      // Please keep these sorted
      case "birthday":
        return create_widget_for_birthday (chunk);
      case "email-addresses":
        return create_widget_for_emails (chunk);
      case "im-addresses":
        return create_widget_for_im_addresses (chunk);
      case "nickname":
        return create_widget_for_nickname (chunk);
      case "notes":
        return create_widget_for_notes (chunk);
      case "phone-numbers":
        return create_widget_for_phone_nrs (chunk);
      case "postal-addresses":
        return create_widget_for_postal_addresses (chunk);
      case "roles":
        return create_widget_for_roles (chunk);
      case "urls":
        return create_widget_for_urls (chunk);
      default:
        debug ("Unsupported property: %s", chunk.property_name);
        return null;
    }
  }

  private Gtk.Label create_persona_store_label (Persona p) {
    var store_name = new Gtk.Label (Utils.format_persona_store_name_for_contact (p));
    var attrList = new Pango.AttrList ();
    attrList.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
    store_name.set_attributes (attrList);
    store_name.halign = Gtk.Align.START;
    store_name.ellipsize = Pango.EllipsizeMode.MIDDLE;

    return store_name;
  }

  private Gtk.Widget create_header (Contact contact) {
    var header = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    header.add_css_class ("contacts-sheet-header");

    var image_frame = new Avatar.for_contact (PROFILE_SIZE, contact);
    // image_frame.vexpand = false;
    // image_frame.valign = Gtk.Align.START;
    header.append (image_frame);

    var name_label = new Gtk.Label ("");
    name_label.label = contact.display_name;
    name_label.hexpand = true;
    name_label.wrap = true;
    name_label.wrap_mode = WORD_CHAR;
    name_label.lines = 4;
    name_label.width_chars = 10;
    name_label.selectable = true;
    name_label.add_css_class ("title-1");
    header.append (name_label);

    return header;
  }

  private Gtk.Widget create_widget_for_roles (Chunk chunk)
      requires (chunk is RolesChunk) {
    unowned var roles_chunk = (RolesChunk) chunk;

    var group = new ContactSheetGroup (chunk);

    for (uint i = 0; i < roles_chunk.get_n_items (); i++) {
      var role = (OrgRole) roles_chunk.get_item (i);
      if (role.is_empty)
        continue;

      //XXX if no role: set "Organisation" tool tip
      var row = new ContactSheetRow (chunk, role.to_string ());

      group.add (row);
    }

    return group;
  }

  private Gtk.Widget create_widget_for_emails (Chunk chunk)
      requires (chunk is EmailAddressesChunk) {
    unowned var emails_chunk = (EmailAddressesChunk) chunk;

    var group = new ContactSheetGroup (chunk);

    for (uint i = 0; i < emails_chunk.get_n_items (); i++) {
      var email = (EmailAddress) emails_chunk.get_item (i);
      if (email.is_empty)
        continue;

      var row = new ContactSheetRow (chunk,
                                     email.raw_address,
                                     email.get_email_address_type ().display_name);

      var button = row.add_button ("mail-send-symbolic");
      button.tooltip_text = _("Send an email to %s").printf (email.raw_address);
      button.clicked.connect (() => {
        unowned var window = get_root () as Gtk.Window;
        Gtk.UriLauncher email_launcher = new Gtk.UriLauncher (email.get_mailto_uri ());
        email_launcher.launch.begin (window, null, (obj, res) => {
          try {
            email_launcher.launch.end (res);
          } catch (Error error) {
            warning ("Could not open new email: %s", error.message);
          }
        });
      });

      group.add (row);
    }

    return group;
  }

  private Gtk.Widget create_widget_for_phone_nrs (Chunk chunk)
      requires (chunk is PhonesChunk) {
    unowned var phones_chunk = (PhonesChunk) chunk;

    var group = new ContactSheetGroup (chunk);

    for (uint i = 0; i < phones_chunk.get_n_items (); i++) {
      var phone = (Phone) phones_chunk.get_item (i);
      if (phone.is_empty)
        continue;

      var row = new ContactSheetRow (chunk,
                                     phone.raw_number,
                                     phone.get_phone_type ().display_name);
      row.set_title_direction (Gtk.TextDirection.LTR);
      group.add (row);
    }

    return group;
  }

  private Gtk.Widget? create_widget_for_im_addresses (Chunk chunk)
      requires (chunk is ImAddressesChunk) {
    // NOTE: We _could_ enable this again, but only for specific services.
    // Right now, this just enables a million "Windows Live Messenger" and
    // "Jabber", ... fields, which are all resting in their respective coffins.
#if 0
    unowned var im_addrs_chunk = (ImAddressesChunk) chunk;

    var group = new ContactSheetGroup (chunk);

    for (uint i = 0; i < im_addrs_chunk.get_n_items (); i++) {
      var im_addr = (ImAddress) im_addrs_chunk.get_item (i);
      if (im_addr.is_empty)
        continue;

        var row = new ContactSheetRow (chunk,
                                       im_addr.address,
                                       ImService.get_display_name (im_addr.protocol));
        group.add (row);
      }
    }

    return group;
#endif
    return null;
  }

  private Gtk.Widget create_widget_for_urls (Chunk chunk)
      requires (chunk is UrlsChunk) {
    unowned var urls_chunk = (UrlsChunk) chunk;

    var group = new ContactSheetGroup (chunk);

    for (uint i = 0; i < urls_chunk.get_n_items (); i++) {
      var url = (Contacts.Url) urls_chunk.get_item (i);
      if (url.is_empty)
        continue;

      var row = new ContactSheetRow (chunk, url.raw_url);

      var button = row.add_button ("external-link-symbolic");
      button.tooltip_text = _("Visit website");
      button.clicked.connect (() => {
        unowned var window = button.get_root () as Gtk.Window;
        Gtk.UriLauncher website_launcher = new Gtk.UriLauncher (url.get_absolute_url ());
        website_launcher.launch.begin (window, null, (obj, res) => {
          try {
            website_launcher.launch.end (res);
          } catch (Error error) {
            warning ("Could not open website: %s", error.message);
          }
        });
      });

      group.add (row);
    }

    return group;
  }

  private Gtk.Widget create_widget_for_nickname (Chunk chunk)
      requires (chunk is NicknameChunk) {
    unowned var nickname_chunk = (NicknameChunk) chunk;

    var row = new ContactSheetRow (chunk, nickname_chunk.nickname);
    return new ContactSheetGroup.single_row (chunk, row);
  }

  private Gtk.Widget create_widget_for_birthday (Chunk chunk)
      requires (chunk is BirthdayChunk) {
    unowned var birthday_chunk = (BirthdayChunk) chunk;

    var birthday_str = birthday_chunk.birthday.to_local ().format ("%x");

    // Compare month and date so we can put a reminder
    string? subtitle = null;

    if (birthday_chunk.is_today (new DateTime.now_local ())) {
      subtitle = _("Their birthday is today! 🎉");
    }

    var row = new ContactSheetRow (chunk, birthday_str, subtitle);
    return new ContactSheetGroup.single_row (chunk, row);
  }

  private Gtk.Widget create_widget_for_notes (Chunk chunk)
      requires (chunk is NotesChunk) {
    unowned var notes_chunk = (NotesChunk) chunk;

    var group = new ContactSheetGroup (chunk);

    for (uint i = 0; i < notes_chunk.get_n_items (); i++) {
      var note = (Note) notes_chunk.get_item (i);
      if (note.is_empty)
        continue;

      var row = new ContactSheetRow (chunk, note.text);
      group.add (row);
    }

    return group;
  }

  private Gtk.Widget create_widget_for_postal_addresses (Chunk chunk)
      requires (chunk is AddressesChunk) {
    unowned var addresses_chunk = (AddressesChunk) chunk;

    // Check outside of the loop if we have a "maps:" URI handler
    var appinfo = AppInfo.get_default_for_uri_scheme ("maps");
    var map_uris_supported = (appinfo != null);
    debug ("Opening 'maps:' URIs supported: %s", map_uris_supported.to_string ());

    var group = new ContactSheetGroup (chunk);

    for (uint i = 0; i < addresses_chunk.get_n_items (); i++) {
      var address = (Address) addresses_chunk.get_item (i);
      if (address.is_empty)
        continue;

      var row = new ContactSheetRow (chunk,
                                     address.to_string ("\n"),
                                     address.get_address_type ().display_name);

      if (map_uris_supported) {
        var button = row.add_button ("map-symbolic");
        button.tooltip_text = _("Show on the map");
        button.clicked.connect (() => {
          unowned var window = button.get_root () as Gtk.Window;
          var uri = address.to_maps_uri ();
          Gtk.UriLauncher map_launcher = new Gtk.UriLauncher (uri);
          map_launcher.launch.begin (window, null, (obj, res) => {
            try {
              map_launcher.launch.end (res);
            } catch (Error error) {
              warning ("Could not open map: %s", error.message);
            }
          });
        });
      }

      group.add (row);
    }

    return group;
  }
}

public class Contacts.ContactSheetGroup : Adw.PreferencesGroup {

  public ContactSheetGroup (Chunk chunk) {
    update_property (Gtk.AccessibleProperty.LABEL, chunk.display_name);
  }

  public ContactSheetGroup.single_row (Chunk chunk,
                                       ContactSheetRow row) {
    this (chunk);

    add (row);
  }
}
