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
using DBus;
using GLib;
using Gdk;

namespace Contacts {
  public bool is_set (string? str) {
    return str != null && str != "";
  }

  public void add_separator (ListBoxRow row, ListBoxRow? before_row) {
    row.set_header (new Separator (Orientation.HORIZONTAL));
  }

  [DBus (name = "org.freedesktop.Application")]
  interface FreedesktopApplication : Object {
    [DBus (name = "ActivateAction")]
    public abstract void ActivateAction (string action,
                                         Variant[] parameter,
                                         HashTable<string, Variant> data) throws Error;
  }

  public void activate_action (string app_id,
                               string action,
                               Variant? parameter,
                               uint32 timestamp) {
    FreedesktopApplication? con = null;

    try {
      string object_path = "/" + app_id.replace(".", "/");
      Display display = Display.get_default ();
      DesktopAppInfo info = new DesktopAppInfo (app_id + ".desktop");
      Gdk.AppLaunchContext context = display.get_app_launch_context ();

      con = Bus.get_proxy_sync (BusType.SESSION, app_id, object_path);
      context.set_timestamp (timestamp);

      Variant[] param_array = {};
      if (parameter != null)
        param_array += parameter;

      var startup_id = context.get_startup_notify_id (info,
                                                      new GLib.List<File>());
      var data = new HashTable<string, Variant>(str_hash, str_equal);
      data.insert ("desktop-startup-id", new Variant.string (startup_id));
      con.ActivateAction (action, param_array, data);
    } catch (Error e) {
      debug ("Failed to activate action" + action);
    }
  }
}

namespace Contacts.Utils {
  public void compose_mail (string email) {
    var mailto_uri = "mailto:" + Uri.escape_string (email, "@" , false);
    try {
      Gtk.show_uri_on_window (null, mailto_uri, 0);
    } catch (Error e) {
      debug ("Couldn't launch URI \"%s\": %s", mailto_uri, e.message);
    }
  }

#if HAVE_TELEPATHY
  public void start_chat (Contact contact, string protocol, string id) {
    var im_persona = contact.find_im_persona (protocol, id);
    var account = (im_persona.store as Tpf.PersonaStore).account;
    var request_dict = new HashTable<string, Value?>(str_hash, str_equal);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_CHANNEL_TYPE,
                         TelepathyGLib.IFACE_CHANNEL_TYPE_TEXT);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_HANDLE_TYPE,
                         (int) TelepathyGLib.HandleType.CONTACT);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_ID,
                         id);

    // TODO: Should really use the event time like:
    // tp_user_action_time_from_x11(gtk_get_current_event_time())
    var request = new TelepathyGLib.AccountChannelRequest(account, request_dict, int64.MAX);
    request.ensure_channel_async.begin ("org.freedesktop.Telepathy.Client.Empathy.Chat", null);
  }

  public void start_call (string contact_id, TelepathyGLib.Account account) {
    var request_dict = new HashTable<string,GLib.Value?>(str_hash, str_equal);

    request_dict.insert (TelepathyGLib.PROP_CHANNEL_CHANNEL_TYPE,
                         TelepathyGLib.IFACE_CHANNEL_TYPE_CALL);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_HANDLE_TYPE,
                         (int) TelepathyGLib.HandleType.CONTACT);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_ID,
                         contact_id);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TYPE_CALL_INITIAL_AUDIO,
                         true);

    var request = new TelepathyGLib.AccountChannelRequest(account, request_dict, int64.MAX);
    request.ensure_channel_async.begin ("org.freedesktop.Telepathy.Client.Empathy.Call", null);
  }
#endif

  public T? get_first<T> (Collection<T> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
  }

  public void grab_entry_focus_no_select (Entry entry) {
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

  public PersonaStore[] get_eds_address_books (Store contacts_store) {
    PersonaStore[] stores = {};
    foreach (var backend in contacts_store.backend_store.enabled_backends.values) {
      foreach (var persona_store in backend.persona_stores.values) {
        if (persona_store.type_id == "eds") {
          stores += persona_store;
        }
      }
    }
    return stores;
  }

  public PersonaStore[] get_eds_address_books_from_backend (BackendStore backend_store) {
    PersonaStore[] stores = {};
    foreach (var backend in backend_store.enabled_backends.values) {
      foreach (var persona_store in backend.persona_stores.values) {
        if (persona_store.type_id == "eds") {
          stores += persona_store;
        }
      }
    }
    return stores;
  }

  public PersonaStore? get_key_file_address_book (Store contacts_store) {
    foreach (var backend in contacts_store.backend_store.enabled_backends.values) {
      foreach (var persona_store in backend.persona_stores.values) {
        if (persona_store.type_id == "key-file") {
          return persona_store;
        }
      }
    }
    return null;
  }


  public void show_error_dialog (string error, Gtk.Window toplevel) {
    var dialog = new Gtk.MessageDialog (toplevel,
                                        Gtk.DialogFlags.MODAL,
                                        Gtk.MessageType.ERROR,
                                        Gtk.ButtonsType.OK,
                                        "%s", error);
    dialog.run();
    dialog.destroy();
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
    res.sort (Contacts.Utils.compare_fields);
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
                                          string property_name, Value new_value) throws PropertyError, IndividualAggregatorError {
    /* FIXME: It should be possible to move these all to being delegates which are
     * passed to the functions which currently call this one; but only once bgo#604827 is fixed. */
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
        yield ((EmailDetails) persona).change_email_addresses ((Set<EmailFieldDetails>) new_value);
        break;
      case "is-favourite":
        yield ((FavouriteDetails) persona).change_is_favourite ((bool) new_value);
        break;
      case "gender":
        yield ((GenderDetails) persona).change_gender ((Gender) new_value);
        break;
      case "groups":
        yield ((GroupDetails) persona).change_groups ((Set<string>) new_value);
        break;
      case "im-addresses":
        yield ((ImDetails) persona).change_im_addresses ((MultiMap<string, ImFieldDetails>) new_value);
        break;
      case "local-ids":
        yield ((LocalIdDetails) persona).change_local_ids ((Set<string>) new_value);
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
        yield ((NoteDetails) persona).change_notes ((Set<NoteFieldDetails>) new_value);
        break;
      case "phone-numbers":
        yield ((PhoneDetails) persona).change_phone_numbers ((Set<PhoneFieldDetails>) new_value);
        break;
      case "postal-addresses":
        yield ((PostalAddressDetails) persona).change_postal_addresses ((Set<PostalAddressFieldDetails>) new_value);
        break;
      case "roles":
        yield ((RoleDetails) persona).change_roles ((Set<RoleFieldDetails>) new_value);
        break;
      case "urls":
        yield ((UrlDetails) persona).change_urls ((Set<UrlFieldDetails>) new_value);
        break;
      case "web-service-addresses":
        yield ((WebServiceDetails) persona).change_web_service_addresses ((MultiMap<string, WebServiceFieldDetails>) new_value);
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
