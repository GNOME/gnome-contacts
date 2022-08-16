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

using Folks;

namespace Contacts {
  public bool is_set (string? str) {
    return str != null && str != "";
  }

  public void add_separator (Gtk.ListBoxRow row, Gtk.ListBoxRow? before_row) {
    row.set_header (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
  }
}

namespace Contacts.Utils {

  public void set_primary_store (Edsf.PersonaStore e_store) {
    eds_source_registry.set_default_address_book (e_store.source);
    var settings = new GLib.Settings ("org.freedesktop.folks");
    settings.set_string ("primary-store", "eds:%s".printf (e_store.id));
  }

  public void compose_mail (string email) {
    var mailto_uri = "mailto:" + Uri.escape_string (email, "@" , false);
    Gtk.show_uri (null, mailto_uri, 0);
  }

  public T? get_first<T> (Gee.Collection<T> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
  }

  public void grab_entry_focus_no_select (Gtk.SearchEntry entry) {
    int start, end;
    if (!entry.get_selection_bounds (out start, out end)) {
      start = end = entry.get_position ();
    }
    entry.grab_focus ();
    entry.select_region (start, end);
  }

  public string[] get_stock_avatars () {
    string[] files = {};
    var system_data_dirs = Environment.get_system_data_dirs ();
    foreach (var data_dir in system_data_dirs) {
      var path = Path.build_filename (data_dir, "pixmaps", "faces");
      Dir? dir = null;
      try {
        dir = Dir.open (path);
      } catch (Error e) {
        debug ("Couldn't open stock avatars folder \"%s\": %s", path, e.message);
      }
      if (dir != null) {
        string? face;
        while ((face = dir.read_name ()) != null) {
          var filename = Path.build_filename (path, face);
          files += filename;
        }
      }
    };
    return files;
  }

  public void show_error_dialog (string error, Gtk.Window toplevel) {
    var dialog = new Adw.MessageDialog (toplevel, null, error);
    dialog.add_response ("close", _("_Close"));
    dialog.default_response = "close";
    dialog.show();
  }

  public bool persona_is_main (Persona persona) {
    var store = persona.store;
    if (!store.is_primary_store)
      return false;

    // Mark google contacts not in "My Contacts" as non-main
    return !persona_is_google_other (persona);
  }

  public bool has_main_persona (Individual individual) {
    var result = false;
    foreach (var p in individual.personas) {
      result |= (p.store.is_primary_store && !persona_is_google_other (p));
    }
    return result;
  }

  public bool is_ignorable (Individual individual) {
    var i = individual.personas.iterator();

    // Look for single-persona individuals
    if (i.next() && !i.has_next ()) {
      var persona_store = i.get().store;

      // Filter out pure key-file persona individuals as these are not very interesting
      if (persona_store.type_id == "key-file")
        return true;

      // Filter out uncertain things like link-local xmpp
      if (persona_store.type_id == "telepathy" &&
          persona_store.trust_level == PersonaStoreTrust.NONE)
        return true;
    }

    return false;
  }

  public bool suggest_link_to (Store store, Individual self, Individual other) {
    if (non_linkable (self) || non_linkable (other))
      return false;

    if (!store.may_suggest_link (self, other))
      return false;

    /* Only connect main contacts with non-mainable contacts.
       non-main contacts can link to any other */
    return !has_main_persona (self) || !has_mainable_persona (other);
  }

  public ListModel fields_to_sorted (Gee.Collection<AbstractFieldDetails> fields) {
    var res = new ListStore (typeof (AbstractFieldDetails));
    foreach (var afd in fields)
      res.append (afd);
    return new Gtk.SortListModel ((owned) res, new AbstractFieldDetailsSorter ());
  }

  public string[] format_address (PostalAddress addr) {
    string[] lines = {};

    if (is_set (addr.street))
      lines += addr.street;

    if (is_set (addr.extension))
      lines += addr.extension;

    if (is_set (addr.locality))
      lines += addr.locality;

    if (is_set (addr.region))
      lines += addr.region;

    if (is_set (addr.postal_code))
      lines += addr.postal_code;

    if (is_set (addr.po_box))
      lines += addr.po_box;

    if (is_set (addr.country))
      lines += addr.country;

    if (is_set (addr.address_format))
      lines += addr.address_format;

    return lines;
  }

  /**
   * Takes an individual's postal address and creates a "maps:q=..." URI for
   * it, which can be launched to use the local system's maps handler
   * (e.g. GNOME Maps).
   *
   * See also https://www.iana.org/assignments/uri-schemes/prov/maps for the
   * "specification"
   */
  public string create_maps_uri (PostalAddress address) {
    var address_parts = string.joinv (" ", Utils.format_address (address));
    return "maps:q=%s".printf (GLib.Uri.escape_string (address_parts));
  }

  /* We claim something is "removable" if at least one persona is removable,
  that will typically unlink the rest. */
  public bool can_remove_personas (Individual individual) {
    foreach (var p in individual.personas)
      if (p.store.can_remove_personas == MaybeBool.TRUE)
        return true;

    return false;
  }

  public ListModel personas_as_list_model (Individual individual) {
    var personas = new ListStore (typeof(Persona));
    foreach (var persona in individual.personas)
      personas.append (persona);
    return personas;
  }

  public Persona? find_primary_persona (Individual individual) {
    foreach (var p in individual.personas)
      if (p.store.is_primary_store)
        return p;

    return null;
  }

  public Persona? find_persona_from_uid (Individual individual, string uid) {
    foreach (var p in individual.personas) {
      if (p.uid == uid)
        return p;
    }
    return null;
  }

  public string format_persona_stores (Individual individual) {
    string stores = "";
    bool first = true;
    foreach (var p in individual.personas) {
      if (!first)
        stores += ", ";
      stores += format_persona_store_name_for_contact (p);
      first = false;
    }
    return stores;
  }

  public string format_persona_store_name (PersonaStore store) {
    if (store.type_id == "eds") {
      // Special-case the local address book
      if (store.id == "system-address-book")
        return _("Local Address Book");

      string? eds_name = lookup_esource_name_by_uid (store.id);
      if (eds_name != null)
        return eds_name;
    }

    return store.display_name;
  }

  /* These are "regular" address book contacts, i.e. they contain a
     persona that would be "main" if that persona was the primary store */
  private bool has_mainable_persona (Individual individual) {
    foreach (var p in individual.personas) {
      if (p.store.type_id == "eds" &&
          !persona_is_google_other (p))
        return true;
    }
    return false;
  }

  /* We never want to suggest linking to google contacts that
     are not My Contacts nor Profiles */
  private bool non_linkable (Individual individual) {
    bool all_unlinkable = true;

    foreach (var p in individual.personas) {
      if (!persona_is_google_other (p))
        all_unlinkable = false;
    }

    return all_unlinkable;
  }

  public bool persona_is_google (Persona persona) {
    return persona.store.type_id == "eds" && esource_uid_is_google (persona.store.id);
  }

  /**
   * Return true only for personas which are in a Google address book, but which
   * are not in the user's "My Contacts" group in the address book.
   */
  public bool persona_is_google_other (Persona persona) {
    if (!persona_is_google (persona))
      return false;

    unowned var p = persona as Edsf.Persona;
    return p != null && !p.in_google_personal_group;
  }

  public string format_persona_store_name_for_contact (Persona persona) {
    unowned var store = persona.store;
    if (store.type_id == "eds") {
      if (persona_is_google_other (persona))
        return _("Google");

      string? eds_name = lookup_esource_name_by_uid_for_contact (store.id);
      if (eds_name != null)
        return eds_name;
    }

    return store.display_name;
  }

  /* Tries to set the property on all persons that have it writeable */
  public async void set_individual_property (Individual individual, string property_name, Value value)
    throws GLib.Error, PropertyError {
      // Need to make a copy here as it could change during the yields
      var personas_copy = individual.personas.to_array ();
      foreach (var p in personas_copy) {
        if (property_name in p.writeable_properties) {
          yield set_persona_property (p, property_name, value);
        }
      }
      //TODO: Add fallback if we can't write to any persona (Do we want to support that?)
    }

  public async void set_persona_property (Persona persona,
                                          string property_name, Value new_value) throws PropertyError, IndividualAggregatorError {
    switch (property_name) {
      case "alias":
        yield ((AliasDetails) persona).change_alias ((string) new_value);
        break;
      case "avatar":
        yield ((AvatarDetails) persona).change_avatar ((LoadableIcon?) new_value);
        break;
      case "birthday":
        yield ((BirthdayDetails) persona).change_birthday ((DateTime?) new_value);
        break;
      case "calendar-event-id":
        yield ((BirthdayDetails) persona).change_calendar_event_id ((string?) new_value);
        break;
      case "email-addresses":
        yield ((EmailDetails) persona).change_email_addresses ((Gee.Set<EmailFieldDetails>) new_value);
        break;
      case "is-favourite":
        yield ((FavouriteDetails) persona).change_is_favourite ((bool) new_value);
        break;
      case "gender":
        yield ((GenderDetails) persona).change_gender ((Gender) new_value);
        break;
      case "groups":
        yield ((GroupDetails) persona).change_groups ((Gee.Set<string>) new_value);
        break;
      case "im-addresses":
        yield ((ImDetails) persona).change_im_addresses ((Gee.MultiMap<string, ImFieldDetails>) new_value);
        break;
      case "local-ids":
        yield ((LocalIdDetails) persona).change_local_ids ((Gee.Set<string>) new_value);
        break;
      case "structured-name":
        yield ((NameDetails) persona).change_structured_name ((StructuredName?) new_value);
        break;
      case "full-name":
        yield ((NameDetails) persona).change_full_name ((string) new_value);
        break;
      case "nickname":
        yield ((NameDetails) persona).change_nickname ((string) new_value);
        break;
      case "notes":
        yield ((NoteDetails) persona).change_notes ((Gee.Set<NoteFieldDetails>) new_value);
        break;
      case "phone-numbers":
        yield ((PhoneDetails) persona).change_phone_numbers ((Gee.Set<PhoneFieldDetails>) new_value);
        break;
      case "postal-addresses":
        yield ((PostalAddressDetails) persona).change_postal_addresses ((Gee.Set<PostalAddressFieldDetails>) new_value);
        break;
      case "roles":
        yield ((RoleDetails) persona).change_roles ((Gee.Set<RoleFieldDetails>) new_value);
        break;
      case "urls":
        yield ((UrlDetails) persona).change_urls ((Gee.Set<UrlFieldDetails>) new_value);
        break;
      case "web-service-addresses":
        yield ((WebServiceDetails) persona).change_web_service_addresses ((Gee.MultiMap<string, WebServiceFieldDetails>) new_value);
        break;
      default:
        critical ("Unknown property '%s' in Contact.set_persona_property().", property_name);
        break;
    }
  }

  // A helper struct to keep track on general properties on how each Persona
  // property should be displayed
  private struct PropertyDisplayInfo {
    string property_name;
    string display_name;
    string icon_name;
  }

  private const PropertyDisplayInfo[] display_infos = {
    { "alias", N_("Alias"), null },
    { "avatar", N_("Avatar"), "emblem-photos-symbolic" },
    { "birthday", N_("Birthday"), "birthday-symbolic" },
    { "calendar-event-id", N_("Calendar event"), "calendar-symbolic" },
    { "email-addresses", N_("Email address"), "mail-unread-symbolic" },
    { "full-name", N_("Full name"), null },
    { "gender", N_("Gender"), null },
    { "groups", N_("Group"), null },
    { "im-addresses", N_("Instant messaging"), "chat-symbolic" },
    { "is-favourite", N_("Favourite"), "emblem-favorite-symbolic" },
    { "local-ids", N_("Local ID"), null },
    { "nickname", N_("Nickname"), "avatar-default-symbolic" },
    { "notes", N_("Note"), "note-symbolic" },
    { "phone-numbers", N_("Phone number"), "phone-symbolic" },
    { "postal-addresses", N_("Address"), "mark-location-symbolic" },
    // TRANSLATORS: This is the role of a contact in an organisation (e.g. CEO)
    { "roles", N_("Role"), "building-symbolic" },
    // TRANSLATORS: This is a field which contains a name decomposed in several
    // parts, rather than a single freeform string for the full name
    { "structured-name", N_("Structured name"), "avatar-default-symbolic" },
    { "urls", N_("Website"), "website-symbolic" },
    { "web-service-addresses", N_("Web service"), null },
  };

  public unowned string get_display_name_for_property (string property_name) {
    foreach (unowned var info in display_infos)
      if (info.property_name == property_name)
        return gettext (info.display_name);
    return_val_if_reached (null);
  }

  public unowned string? get_icon_name_for_property (string property_name) {
    foreach (unowned var info in display_infos)
      if (info.property_name == property_name)
        return info.icon_name;
    return null;
  }
}
