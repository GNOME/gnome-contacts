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

public class Contacts.Contact : GLib.Object  {
  private weak Store store;
  public bool is_main;

  public Individual individual;
  uint changed_id;

  public Persona? fake_persona = null;

  public static bool persona_has_writable_property (Persona persona, string property) {
    // TODO: This should check the writibility on the FakePersona store,
    // but that is not availible in folks yet
    if (persona is FakePersona)
      return true;

    foreach (unowned string p in persona.writeable_properties) {
      if (p == property)
	return true;
    }
    return false;
  }

  public signal void changed ();

  /**
   * There are 2 reasons why we want to hide a contact in the UI:
   * 1. The contact is going to be deleted (but isn't yet, since we support undoing)
   * 2. The contact comes from an uninteresting or untrusted source.
   */
  public bool hidden {
    get { return this.ignored || this.to_be_deleted; }
    set {
      if (this.to_be_deleted != value) {
        this.to_be_deleted = value;
        notify_property("hidden");
      }
    }
  }
  private bool to_be_deleted; // this.hidden, part 1
  private bool ignored;       // this.hidden, part 2

  public Contact (Store store, Individual i) {
    this.store = store;
    this.individual = i;
    this.individual.set_data ("contact", this);
    this.individual.notify.connect(notify_cb);

    this.ignored = is_ignorable ();
    this.is_main = calc_is_main ();
  }

  public static unowned Contact from_individual (Individual i) {
    return i.get_data ("contact");
  }

  public static bool persona_is_main (Persona persona) {
    var store = persona.store;
    if (!store.is_primary_store)
      return false;

    // Mark google contacts not in "My Contacts" as non-main
    return !persona_is_google_other (persona);
  }

  private bool calc_is_main () {
    foreach (var p in this.individual.personas)
      if (persona_is_main (p))
        return true;

    return false;
  }

  public void replace_individual (Individual new_individual) {
    individual.notify.disconnect(notify_cb);
    individual = new_individual;
    individual.set_data ("contact", this);
    individual.notify.connect(notify_cb);
    queue_changed ();
  }

  public void remove () {
    unqueue_changed ();
    individual.notify.disconnect(notify_cb);
  }

  private bool is_ignorable () {
    var i = this.individual.personas.iterator();

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

  public bool has_email (string email_address) {
    var addrs = individual.email_addresses;
    foreach (var detail in addrs) {
      if (detail.value == email_address)
	return true;
    }
    return false;
  }

  private static bool has_pref (AbstractFieldDetails details) {
    var evolution_pref = details.get_parameter_values ("x-evolution-ui-slot");
    if (evolution_pref != null && Utils.get_first (evolution_pref) == "1")
      return true;

    foreach (var param in details.parameters["type"]) {
      if (param.ascii_casecmp ("PREF") == 0)
        return true;
    }
    return false;
  }

  private static TypeSet select_typeset_from_fielddetails (AbstractFieldDetails a) {
    if (a is EmailFieldDetails)
      return TypeSet.email;
    if (a is PhoneFieldDetails)
      return TypeSet.phone;
    return TypeSet.general;
  }

  public static int compare_fields (void* _a, void* _b) {
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

  public static Gee.List<T> sort_fields<T> (Collection<T> fields) {
    var res = new ArrayList<T>();
    res.add_all (fields);
    res.sort (Contact.compare_fields);
    return res;
  }

  public static string[] format_address (PostalAddress addr) {
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
  public Tpf.Persona? find_im_persona (string protocol, string im_address) {
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

  private bool changed_cb () {
    this.changed_id = 0;
    this.is_main = calc_is_main ();
    changed ();
    return false;
  }

  private void unqueue_changed () {
    if (changed_id != 0) {
      Source.remove (changed_id);
      changed_id = 0;
    }
  }

  public void queue_changed () {
    if (this.changed_id == 0)
      this.changed_id = Idle.add (changed_cb);
  }

  private void notify_cb (ParamSpec pspec) {
    queue_changed ();
  }

  /* We claim something is "removable" if at least one persona is removable,
     that will typically unlink the rest. */
  public bool can_remove_personas () {
    foreach (var p in this.individual.personas)
      if (p.store.can_remove_personas == MaybeBool.TRUE)
        return true;

    return false;
  }

  public async void remove_personas () throws Folks.PersonaStoreError {
    var personas = new HashSet<Persona> ();
    foreach (var p in this.individual.personas)
      if (p.store.can_remove_personas == MaybeBool.TRUE)
        personas.add (p);

    foreach (var persona in personas)
      yield persona.store.remove_persona (persona);
  }

  public async Persona ensure_primary_persona () throws IndividualAggregatorError, ContactError, PropertyError {
    Persona? p = find_primary_persona ();
    if (p != null)
      return p;

    // There is no primary persona, so we link all the current personas
    // together. This will create a new persona in the primary store
    // that links all the personas together

    // HACK-ATTACK:
    // We need to create a fake persona since link_personas is a no-op
    // for single-persona sets
    var persona_set = new HashSet<Persona>();
    persona_set.add_all (individual.personas);
    if (persona_set.size == 1)
      persona_set.add (new FakePersona (this.store, this));

    yield store.aggregator.link_personas (persona_set);

    p = find_primary_persona ();
    if (p == null)
      throw new ContactError.NO_PRIMARY (_("Unexpected internal error: created contact was not found"));

    return p;
  }

  public Gee.List<Persona> get_personas_for_display () {
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

  public Persona? find_primary_persona () {
    foreach (var p in individual.personas)
      if (p.store.is_primary_store)
        return p;

    return null;
  }

  public Persona? find_persona_from_uid (string uid) {
    foreach (var p in individual.personas) {
      if (p.uid == uid)
	return p;
    }
    if (uid == "uid-fake-persona" && this.fake_persona != null)
      return this.fake_persona;

    return null;
  }

  public string format_persona_stores () {
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

  public static string format_persona_store_name (PersonaStore store) {
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
  public bool has_mainable_persona () {
    foreach (var p in individual.personas) {
      if (p.store.type_id == "eds" &&
	  !persona_is_google_other (p))
	return true;
    }
    return false;
  }

  /* We never want to suggest linking to google contacts that
     are not My Contacts nor Profiles */
  private bool non_linkable () {
    bool all_unlinkable = true;

    foreach (var p in individual.personas) {
      if (!persona_is_google_other (p) ||
	  persona_is_google_profile (p))
	all_unlinkable = false;
    }

    return all_unlinkable;
  }

  public bool suggest_link_to (Contact other) {
    if (this.non_linkable () || other.non_linkable ())
      return false;

    if (!this.store.may_suggest_link (this, other))
      return false;

    /* Only connect main contacts with non-mainable contacts.
       non-main contacts can link to any other */
    return !this.is_main || !other.has_mainable_persona();
  }

  private static bool persona_is_google (Persona persona) {
    return persona.store.type_id == "eds" && esource_uid_is_google (persona.store.id);
  }

  /**
   * Return true only for personas which are in a Google address book, but which
   * are not in the user's "My Contacts" group in the address book.
   */
  public static bool persona_is_google_other (Persona persona) {
    if (!persona_is_google (persona))
      return false;

    var p = persona as Edsf.Persona;
    return p != null && !p.in_google_personal_group;
  }

  public static bool persona_is_google_profile (Persona persona) {
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

  public static string format_persona_store_name_for_contact (Persona persona) {
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

  /* Tries to set the property on all persons that have it writeable, and
   * if none, creates a new persona and writes to it, returning the new
   * persona.
   */
  public async Persona? set_individual_property (string property_name, Value value)
      throws GLib.Error, PropertyError {
    bool did_set = false;
    // Need to make a copy here as it could change during the yields
    var personas_copy = this.individual.personas.to_array ();
    foreach (var p in personas_copy) {
      if (property_name in p.writeable_properties) {
	did_set = true;
	yield Contact.set_persona_property (p, property_name, value);
      }
    }

    if (!did_set) {
      var fake = new FakePersona (this.store, this);
      return yield fake.make_real_and_set (property_name, value);
    }
    return null;
  }

  public static async Persona? create_primary_persona_for_details (Folks.PersonaStore store, HashTable<string, Value?> details) throws GLib.Error {
    var p = yield store.add_persona_from_details (details);
    return p;
  }

  public static async void set_persona_property (Persona persona,
						   string property_name, Value new_value) throws PropertyError, IndividualAggregatorError, ContactError, PropertyError {
    if (persona is FakePersona) {
      var fake = persona as FakePersona;
      yield fake.make_real_and_set (property_name, new_value);
      return;
    }

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

  public void keep_widget_uptodate (Widget w, owned Gtk.Callback callback) {
    callback(w);
    ulong id = this.changed.connect ( () => { callback(w); });
    w.destroy.connect (() => { this.disconnect (id); });
  }

#if HAVE_TELEPATHY
  public void fetch_contact_info () {
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

public class Contacts.FakePersonaStore : PersonaStore {
  public static FakePersonaStore _the_store;
  public static FakePersonaStore the_store() {
    if (_the_store == null)
      _the_store = new FakePersonaStore ();
    return _the_store;
  }
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;

  public override string type_id { get { return "fake"; } }

  public FakePersonaStore () {
    Object (id: "uri", display_name: "fake store");
    this._personas = new HashMap<string, Persona> ();
    this._personas_ro = this._personas.read_only_view;
  }

  public override Map<string, Persona> personas
    {
      get { return this._personas_ro; }
    }

  public override MaybeBool can_add_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_alias_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_group_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_remove_personas { get { return MaybeBool.FALSE; } }
  public override bool is_prepared  { get { return true; } }
  public override bool is_quiescent  { get { return true; } }
  private string[] _always_writeable_properties = {};
  public override string[] always_writeable_properties { get { return this._always_writeable_properties; } }
  public override async void prepare () throws GLib.Error { }
  public override async Persona? add_persona_from_details (HashTable<string, Value?> details) throws Folks.PersonaStoreError {
    return null;
  }
  public override async void remove_persona (Persona persona) throws Folks.PersonaStoreError {
  }
}

public class Contacts.FakePersona : Persona {
  public Contact contact;
  private class PropVal {
    public string property;
    public Value value;
  }
  private ArrayList<PropVal> prop_vals;
  private bool now_real;
  private bool has_full_name;

  public static FakePersona? maybe_create_for (Store store, Contact contact) {
    var primary_persona = contact.find_primary_persona ();

    if (primary_persona != null)
      return null;

    foreach (var p in contact.individual.personas) {
      // Don't fake a primary persona if we have an eds
      // persona on a non-readonly store
      if (p.store.type_id == "eds" &&
	  p.store.can_add_personas == MaybeBool.TRUE &&
	  p.store.can_remove_personas == MaybeBool.TRUE)
	return null;
    }

    return new FakePersona (store, contact);
  }

  private const string[] _linkable_properties = {};
  private const string[] _writeable_properties = {};
  public override string[] linkable_properties
    {
      get { return _linkable_properties; }
    }

  public override string[] writeable_properties
    {
      get { return _writeable_properties; }
    }

  public async Persona? make_real_and_set (string property,
					   Value value) throws IndividualAggregatorError, ContactError, PropertyError {
    var v = new PropVal ();
    v.property = property;
    v.value = value;
    if (property == "full-name")
      has_full_name = true;

    if (prop_vals == null) {
      prop_vals = new ArrayList<PropVal> ();
      prop_vals.add (v);
      Persona p = yield contact.ensure_primary_persona ();
      if (!has_full_name)
	p.set ("full-name", contact.individual.display_name);
      foreach (var pv in prop_vals) {
	yield Contact.set_persona_property (p, pv.property, pv.value);
      }
      now_real = true;
      return p;
    } else {
      assert (!now_real);
      prop_vals.add (v);
      return null;
    }
  }

  public FakePersona (Store? store, Contact contact) {
    Object (display_id: "display_id",
            uid: "uid-fake-persona",
            iid: "iid",
            store: store.aggregator.primary_store ?? FakePersonaStore.the_store(),
            is_user: false);
    this.contact = contact;
    this.contact.fake_persona = this;
  }
}
