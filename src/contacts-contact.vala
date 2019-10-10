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

public errordomain ContactError {
  NOT_IMPLEMENTED,
  NO_PRIMARY
}

namespace Contacts.ContactUtils {
  public bool persona_is_main (Persona persona) {
    var store = persona.store;
    if (!store.is_primary_store)
      return false;

    // Mark google contacts not in "My Contacts" as non-main
    return !persona_is_google_other (persona);
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
    //return !this.is_main || !other.has_mainable_persona();
    return true;
  }

  private bool has_pref (AbstractFieldDetails details) {
    var evolution_pref = details.get_parameter_values ("x-evolution-ui-slot");
    if (evolution_pref != null && Utils.get_first (evolution_pref) == "1")
      return true;

    foreach (var param in details.parameters["type"]) {
      if (param.ascii_casecmp ("PREF") == 0)
        return true;
    }
    return false;
  }

  private TypeSet select_typeset_from_fielddetails (AbstractFieldDetails a) {
    if (a is EmailFieldDetails)
      return TypeSet.email;
    if (a is PhoneFieldDetails)
      return TypeSet.phone;
    return TypeSet.general;
  }

  public int compare_fields (void* _a, void* _b) {
    var a = (AbstractFieldDetails) _a;
    var b = (AbstractFieldDetails) _b;

    // Fields with a PREF hint always go first (see VCard PREF attribute)
    var a_has_pref = has_pref (a);
    if (a_has_pref != has_pref (b))
      return (a_has_pref)? -1 : 1;

    // sort by field type first (e.g. "Home", "Work")
    var type_set = select_typeset_from_fielddetails (a);
    var result = type_set.format_type (a).ascii_casecmp (type_set.format_type (b));
    if (result != 0)
      return result;

    // Try to compare by value if types are equal
    var aa = a as AbstractFieldDetails<string>;
    var bb = b as AbstractFieldDetails<string>;
    if (aa != null && bb != null)
      return strcmp (aa.value, bb.value);

    // No heuristics to fall back to.
    warning ("Unsupported AbstractFieldDetails value type");
    return 0;
  }

  public Gee.List<T> sort_fields<T> (Collection<T> fields) {
    var res = new ArrayList<T>();
    res.add_all (fields);
    res.sort (ContactUtils.compare_fields);
    return res;
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

#if HAVE_TELEPATHY
  public Tpf.Persona? find_im_persona (Individual individual, string protocol, string im_address) {
    var iid = protocol + ":" + im_address;
    foreach (var p in individual.personas) {
      var tp = p as Tpf.Persona;
      if (tp != null && tp.iid == iid) {
        return tp;
      }
    }
    return null;
  }
#endif

  /* We claim something is "removable" if at least one persona is removable,
  that will typically unlink the rest. */
  public bool can_remove_personas (Individual individual) {
    foreach (var p in individual.personas)
      if (p.store.can_remove_personas == MaybeBool.TRUE)
        return true;

    return false;
  }

  public Gee.List<Persona> get_personas_for_display (Individual individual) {
    CompareDataFunc<Persona> compare_persona_by_store = (a, b) => {
      var store_a = a.store;
      var store_b = b.store;

      // In the same store, sort Google 'other' contacts last
      if (store_a == store_b) {
        if (!persona_is_google (a))
          return 0;

        var a_is_other = persona_is_google_other (a);
        if (a_is_other != persona_is_google_other (b))
          return a_is_other? 1 : -1;
      }

      // Sort primary stores before others
      if (store_a.is_primary_store != store_b.is_primary_store)
        return (store_a.is_primary_store)? -1 : 1;

      // E-D-S stores get prioritized
      if ((store_a.type_id == "eds") != (store_b.type_id == "eds"))
        return (store_a.type_id == "eds")? -1 : 1;

      // Normal case: use alphabetical sorting
      return strcmp (store_a.id, store_b.id);
    };

    var persona_list = new ArrayList<Persona>();
    foreach (var persona in individual.personas)
      if (persona.store.type_id != "key-file")
        persona_list.add (persona);

    persona_list.sort ((owned) compare_persona_by_store);
    return persona_list;
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
      string? eds_name = lookup_esource_name_by_uid (store.id);
      if (eds_name != null)
        return eds_name;
    }
#if HAVE_TELEPATHY
    if (store.type_id == "telepathy") {
      var account = (store as Tpf.PersonaStore).account;
      return Contacts.ImService.get_display_name (account.service);
    }
#endif

    return store.display_name;
  }

  /* These are "regular" address book contacts, i.e. they contain a
     persona that would be "main" if that persona was the primary store */
  public bool has_mainable_persona (Individual individual) {
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
      if (!persona_is_google_other (p) ||
          persona_is_google_profile (p))
        all_unlinkable = false;
    }

    return all_unlinkable;
  }

  private bool persona_is_google (Persona persona) {
    return persona.store.type_id == "eds" && esource_uid_is_google (persona.store.id);
  }

  /**
   * Return true only for personas which are in a Google address book, but which
   * are not in the user's "My Contacts" group in the address book.
   */
  public bool persona_is_google_other (Persona persona) {
    if (!persona_is_google (persona))
      return false;

    var p = persona as Edsf.Persona;
    return p != null && !p.in_google_personal_group;
  }

  public bool persona_is_google_profile (Persona persona) {
    if (!persona_is_google_other (persona))
      return false;

    var u = persona as UrlDetails;
    if (u != null && u.urls.size == 1) {
      foreach (var url in u.urls) {
        if (/https?:\/\/www.google.com\/profiles\/[0-9]+$/.match(url.value))
          return true;
      }
    }
    return false;
  }

  public string format_persona_store_name_for_contact (Persona persona) {
    var store = persona.store;
    if (store.type_id == "eds") {
      if (persona_is_google_profile (persona))
        return _("Google Circles");
      else if (persona_is_google_other (persona))
        return _("Google");

      string? eds_name = lookup_esource_name_by_uid_for_contact (store.id);
      if (eds_name != null)
        return eds_name;
    }
#if HAVE_TELEPATHY
    if (store.type_id == "telepathy") {
      var account = (store as Tpf.PersonaStore).account;
      return Contacts.ImService.get_display_name (account.service);
    }
#endif

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
      //TODO: Add fallback if we can't write to any persona (Do we wan't to support that?)
    }

  public async void set_persona_property (Persona persona,
                                          string property_name, Value new_value) throws PropertyError, IndividualAggregatorError, ContactError, PropertyError {
    /* FIXME: It should be possible to move these all to being delegates which are
     * passed to the functions which currently call this one; but only once bgo#604827 is fixed. */
    switch (property_name) {
      case "alias":
        yield (persona as AliasDetails).change_alias ((string) new_value);
        break;
      case "avatar":
        yield (persona as AvatarDetails).change_avatar ((LoadableIcon?) new_value);
        break;
      case "birthday":
        yield (persona as BirthdayDetails).change_birthday ((DateTime?) new_value);
        break;
      case "calendar-event-id":
        yield (persona as BirthdayDetails).change_calendar_event_id ((string?) new_value);
        break;
      case "email-addresses":
        yield (persona as EmailDetails).change_email_addresses ((Set<EmailFieldDetails>) new_value);
        break;
      case "is-favourite":
        yield (persona as FavouriteDetails).change_is_favourite ((bool) new_value);
        break;
      case "gender":
        yield (persona as GenderDetails).change_gender ((Gender) new_value);
        break;
      case "groups":
        yield (persona as GroupDetails).change_groups ((Set<string>) new_value);
        break;
      case "im-addresses":
        yield (persona as ImDetails).change_im_addresses ((MultiMap<string, ImFieldDetails>) new_value);
        break;
      case "local-ids":
        yield (persona as LocalIdDetails).change_local_ids ((Set<string>) new_value);
        break;
      case "structured-name":
        yield (persona as NameDetails).change_structured_name ((StructuredName?) new_value);
        break;
      case "full-name":
        yield (persona as NameDetails).change_full_name ((string) new_value);
        break;
      case "nickname":
        yield (persona as NameDetails).change_nickname ((string) new_value);
        break;
      case "notes":
        yield (persona as NoteDetails).change_notes ((Set<NoteFieldDetails>) new_value);
        break;
      case "phone-numbers":
        yield (persona as PhoneDetails).change_phone_numbers ((Set<PhoneFieldDetails>) new_value);
        break;
      case "postal-addresses":
        yield (persona as PostalAddressDetails).change_postal_addresses ((Set<PostalAddressFieldDetails>) new_value);
        break;
      case "roles":
        yield (persona as RoleDetails).change_roles ((Set<RoleFieldDetails>) new_value);
        break;
      case "urls":
        yield (persona as UrlDetails).change_urls ((Set<UrlFieldDetails>) new_value);
        break;
      case "web-service-addresses":
        yield (persona as WebServiceDetails).change_web_service_addresses ((MultiMap<string, WebServiceFieldDetails>) new_value);
        break;
      default:
        critical ("Unknown property '%s' in Contact.set_persona_property().", property_name);
        break;
    }
  }

#if HAVE_TELEPATHY
  public void fetch_contact_info (Individual individual) {
    /* TODO: Ideally Folks should have API for this (#675131) */
    foreach (var p in individual.personas) {
      var tp = p as Tpf.Persona;
      if (tp != null) {
        tp.contact.request_contact_info_async.begin (null);
      }
    }
  }
#endif
}
