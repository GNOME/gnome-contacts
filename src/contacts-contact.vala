/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
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
using TelepathyGLib;
using Geocode;

public errordomain ContactError {
  NOT_IMPLEMENTED,
  NO_PRIMARY
}

public class Contacts.Contact : GLib.Object  {
  public const int LIST_AVATAR_SIZE = 48;
  public const int SMALL_AVATAR_SIZE = 54;

  public Store store;
  public bool is_main;

  public Individual individual;
  uint changed_id;
  bool changed_personas;

  public Persona? fake_persona = null;

  private Gdk.Pixbuf? _small_avatar;
  public Gdk.Pixbuf small_avatar {
    get {
      if (_small_avatar == null) {
	var pixbuf = load_icon (individual.avatar, SMALL_AVATAR_SIZE);
	if (pixbuf == null)
	  pixbuf = draw_fallback_avatar (SMALL_AVATAR_SIZE, this);
	_small_avatar = frame_icon (pixbuf);
      }
      return _small_avatar;
    }
  }

  private Variant? _avatar_icon_data;
  public Variant? avatar_icon_data {
    get {
      if (individual.avatar == null)
        return null;

      if (_avatar_icon_data == null) {

        if (small_avatar == null)
          return null;

        _avatar_icon_data = small_avatar.serialize ();
      }
      return _avatar_icon_data;
    }
  }

  public string display_name {
    get {
      unowned string? name = individual.full_name;
      if (is_set (name))
	return name;
      unowned string? alias = individual.alias;
      if (is_set (alias))
	return alias;
      unowned string? nickname = individual.nickname;
      if (is_set (nickname))
	return nickname;
      foreach (var email in individual.email_addresses) {
	string? e = email.value;
	if (is_set (e))
	  return email.value;
      }
      return "";
    }
  }

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

  public static string get_display_name_for_persona (Persona persona) {
    var name_details = persona as NameDetails;
    var alias_details = persona as AliasDetails;
    var email_details = persona as EmailDetails;

    if (name_details != null) {
      unowned string? name = name_details.full_name;
      if (is_set (name))
	return name;
    }
    if (alias_details != null) {
      unowned string? alias = alias_details.alias;
      if (is_set (alias))
	return alias;
    }
    if (name_details != null) {
      unowned string? nickname = name_details.nickname;
      if (is_set (nickname))
	return nickname;
    }
    if (email_details != null) {
      foreach (var email in email_details.email_addresses) {
	string e = email.value;
	if (is_set (e))
	  return e;
      }
    }
    return "";
  }

  public unichar initial_letter {
    get {
      string name = display_name;
      if (name.length == 0)
	return 0;
      return name.get_char ().totitle ();
    }
  }

  private string filter_data;

  public signal void changed ();
  public signal void personas_changed ();

  private bool _is_hidden;
  private bool _is_hidden_uptodate;
  private bool _is_hidden_to_delete;

  private bool _get_is_hidden () {
    // Don't show the user itself
    if (individual.is_user)
      return true;

    // Contact has been deleted (but this is not actually posted, for undo support)
    if (_is_hidden_to_delete)
      return true;

    var personas = individual.personas;
    var i = personas.iterator();
    // Look for single-persona individuals
    if (i.next() && !i.has_next ()) {
      var persona = i.get();
      var store = persona.store;

      // Filter out pure key-file persona individuals as these are
      // not very interesting
      if (store.type_id == "key-file")
	return true;

      // Filter out uncertain things like link-local xmpp
      if (store.type_id == "telepathy" &&
	  store.trust_level == PersonaStoreTrust.NONE)
	return true;

    }

    return false;
  }

  public bool is_hidden {
    get {
      if (!_is_hidden_uptodate) {
	_is_hidden = _get_is_hidden ();
	_is_hidden_uptodate = true;
      }
      return _is_hidden;
    }
  }

  public void hide () {
    _is_hidden_to_delete = true;

    queue_changed (false);
  }

  public void show () {
    _is_hidden_to_delete = false;

    queue_changed (false);
  }

  public static Contact from_individual (Individual i) {
    return i.get_data ("contact");
  }

  private void persona_notify_cb (ParamSpec pspec) {
    queue_changed (false);
  }

  private void connect_persona (Persona p) {
    var tp = p as Tpf.Persona;
    if (tp != null && tp.contact != null)
      tp.contact.notify["client-types"].connect (persona_notify_cb);
  }

  private void disconnect_persona (Persona p) {
    SignalHandler.disconnect_by_func (individual, (void *)persona_notify_cb, this);
    var tp = p as Tpf.Persona;
    if (tp != null && tp.contact != null)
      SignalHandler.disconnect_by_func (tp.contact, (void *)persona_notify_cb, this);
  }

  public static bool persona_is_main (Persona persona) {
    var store = persona.store;
    if (!store.is_primary_store)
      return false;

    // Mark google contacts not in "My Contacts" as non-main
    if (persona_is_google_other (persona)) {
      return false;
    }

    return true;
  }

  private bool calc_is_main () {
    var res = false;
    foreach (var p in individual.personas) {
      if (persona_is_main (p))
	res = true;
    }
    return res;
  }

  public Contact (Store store, Individual i) {
    this.store = store;
    individual = i;
    individual.set_data ("contact", this);

    is_main = calc_is_main ();
    foreach (var p in individual.personas) {
      connect_persona (p);
    }

    individual.personas_changed.connect ( (added, removed) => {
	foreach (var p in added)
	  connect_persona (p);
	foreach (var p in removed)
	  disconnect_persona (p);
	queue_changed (true);
      });

    update ();

    individual.notify.connect(notify_cb);
  }

  public void replace_individual (Individual new_individual) {
    foreach (var p in individual.personas) {
      disconnect_persona (p);
    }
    individual.notify.disconnect(notify_cb);
    individual = new_individual;
    individual.set_data ("contact", this);
    foreach (var p in individual.personas) {
      connect_persona (p);
    }
    _small_avatar = null;
    _avatar_icon_data = null;
    individual.notify.connect(notify_cb);
    queue_changed (true);
  }

  public void remove () {
    unqueue_changed ();
    foreach (var p in individual.personas) {
      disconnect_persona (p);
    }
    individual.notify.disconnect(notify_cb);
  }

  public bool has_email (string email_address) {
    var addrs = individual.email_addresses;
    foreach (var detail in addrs) {
      if (detail.value == email_address)
	return true;
    }
    return false;
  }

  public bool has_birthday () {
    return individual.birthday != null;
  }

  public bool has_nickname () {
    return individual.nickname != null &&
           individual.nickname != "";
  }

  public bool has_notes () {
    foreach (var p in get_personas_for_display ()) {
      var note_details = p as NoteDetails;
      if (note_details != null) {
	foreach (var note in note_details.notes) {
	  if (note.value != "")
	    return true;
	}
      }
    }
    return false;
  }

  public bool contains_strings (string [] strings) {
    foreach (string i in strings) {
      if (! (i in filter_data))
	return false;
    }
    return true;
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
  
  private static int compare_fields_type (TypeSet type_set, AbstractFieldDetails a, AbstractFieldDetails b) {
    string a_type = type_set.format_type (a);
    string b_type = type_set.format_type (b);
    return a_type.ascii_casecmp (b_type);
  }
  
  private static TypeSet select_typeset_from_fielddetails (AbstractFieldDetails a) {
    if (a is EmailFieldDetails)
      return TypeSet.email;
    else if (a is PhoneFieldDetails)
      return TypeSet.phone;
    else
      return TypeSet.general; 
  }

  public static int compare_fields (void *_a, void *_b) {
    AbstractFieldDetails *a = (AbstractFieldDetails *)_a;
    AbstractFieldDetails *b = (AbstractFieldDetails *)_b;

    /* Compare by pref */
    bool first_a = has_pref (a);
    bool first_b = has_pref (b);
    if (first_a != first_b) {
      if (first_a)
	return -1;
      else
	return 1;
    }
    
    // compare by type
    TypeSet field_type_set = select_typeset_from_fielddetails (a);    
    int result = compare_fields_type (field_type_set, a, b);
    if (result != 0) {
      return result;
    }
    
    // compare by value if types are equal
    if (a is EmailFieldDetails || a is PhoneFieldDetails) {
      var aa = a as AbstractFieldDetails<string>;
      var bb = b as AbstractFieldDetails<string>;
      return strcmp (aa.value, bb.value);
    }

    warning ("Unsupported AbstractFieldDetails value type");

    return 0;
  }

  public static ArrayList<T> sort_fields<T> (Collection<T> fields) {
    var res = new ArrayList<T>();
    res.add_all (fields);
    res.sort (Contact.compare_fields);
    return res;
  }

  public static async Place geocode_address (PostalAddress addr) {
    SourceFunc callback = geocode_address.callback;
    var params = new HashTable<string, GLib.Value?>(str_hash, str_equal);

    if (is_set (addr.street))
      params.insert("street", addr.street);

    if (is_set (addr.locality))
      params.insert("locality", addr.locality);

    if (is_set (addr.region))
      params.insert("region", addr.region);

    if (is_set (addr.country))
      params.insert("country", addr.country);

    Place? place = null;
    var forward = new Forward.for_params (params);
    forward.search_async.begin (null, (object, res) => {
        try {
          var places = forward.search_async.end (res);

          place = places.nth_data (0);
          callback ();
        } catch (GLib.Error e) {
          debug ("No geocode result found for contact");
          callback ();
        }
      });
    yield;
    return place;
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

  public enum ImDisplay {
    DEFAULT,           /* $id ($service) */
    ALIAS_SERVICE      /* $alias ($service) */
  }

  private struct ImData {
    unowned string service;
    unowned string display_name;
    ImDisplay display;
  }

  public static string format_im_service (string service, out ImDisplay display) {
    const ImData[] data = {
      { "google-talk", N_("Google Talk") },
      { "ovi-chat", N_("Ovi Chat") },
      { "facebook", N_("Facebook"), ImDisplay.ALIAS_SERVICE },
      { "lj-talk", N_("Livejournal") },
      { "aim", N_("AOL Instant Messenger") },
      { "gadugadu", N_("Gadu-Gadu") },
      { "groupwise", N_("Novell Groupwise") },
      { "icq", N_("ICQ")},
      { "irc", N_("IRC")},
      { "jabber", N_("Jabber")},
      { "local-xmpp", N_("Local network")},
      { "msn", N_("Windows Live Messenger")},
      { "myspace", N_("MySpace")},
      { "mxit", N_("MXit")},
      { "napster", N_("Napster")},
      { "qq", N_("Tencent QQ")},
      { "sametime", N_("IBM Lotus Sametime")},
      { "silc", N_("SILC")},
      { "sip", N_("sip")},
      { "skype", N_("Skype")},
      { "tel", N_("Telephony")},
      { "trepia", N_("Trepia")},
      { "yahoo", N_("Yahoo! Messenger")},
      { "yahoojp", N_("Yahoo! Messenger")},
      { "zephyr", N_("Zephyr")}
    };

    foreach (var d in data) {
      if (d.service == service) {
	display = d.display;
	return dgettext (Config.GETTEXT_PACKAGE, d.display_name);
      }
    }

    display = ImDisplay.DEFAULT;
    return service;
  }

  private bool changed_cb () {
    changed_id = 0;
    var changed_personas = this.changed_personas;
    this.changed_personas = false;
    this.is_main = calc_is_main ();
    update ();
    changed ();
    if (changed_personas)
      personas_changed ();
    return false;
  }

  private void unqueue_changed () {
    if (changed_id != 0) {
      Source.remove (changed_id);
      changed_id = 0;
    }
  }

  public void queue_changed (bool is_persona_change) {
    _is_hidden_uptodate = false;
    changed_personas |= is_persona_change;

    if (changed_id != 0)
      return;

    changed_id = Idle.add (changed_cb);
  }

  private void notify_cb (ParamSpec pspec) {
    if (pspec.get_name () == "avatar") {
      _small_avatar = null;
      _avatar_icon_data = null;
    }
    queue_changed (false);
  }

  private void update_filter_data () {
    var builder = new StringBuilder ();
    if (individual.alias != null) {
      builder.append (Utils.canonicalize_for_search (individual.alias));
      builder.append_unichar (' ');
    }
    if (individual.full_name != null) {
      builder.append (Utils.canonicalize_for_search (individual.full_name));
      builder.append_unichar (' ');
    }
    if (individual.nickname != null) {
      builder.append (Utils.canonicalize_for_search (individual.nickname));
      builder.append_unichar (' ');
    }
    var im_addresses = individual.im_addresses;
    foreach (var detail in im_addresses.get_values ()) {
      var addr = detail.value;
      builder.append (addr.casefold ());
      builder.append_unichar (' ');
    }
    var emails = individual.email_addresses;
    foreach (var email in emails) {
      builder.append (email.value.casefold ());
      builder.append_unichar (' ');
    }
    var phone_numbers = individual.phone_numbers;
    foreach (var phone in phone_numbers) {
      builder.append (phone.value.casefold ());
      builder.append_unichar (' ');
    }
    filter_data = builder.str;
  }

  private void update () {
    foreach (var email in individual.email_addresses) {
      TypeSet.general.type_seen (email);
    }

    foreach (var phone in individual.phone_numbers) {
      TypeSet.phone.type_seen (phone);
    }

    update_filter_data ();
  }

  // TODO: This should be async, but the vala bindings are broken (bug #649875)
  private Gdk.Pixbuf load_icon (LoadableIcon ?file, int size) {
    Gdk.Pixbuf? res = null;
    if (file != null) {
      try {
	Cancellable c = new Cancellable ();
	var stream = file.load (size, null, c);
	res = new Gdk.Pixbuf.from_stream_at_scale (stream, size, size, true, c);
      } catch (GLib.Error e) {
	warning ("error loading avatar %s\n", e.message);
      }
    }

    return res;
  }

  public static Gdk.Pixbuf frame_icon (Gdk.Pixbuf icon) {
    int w = icon.get_width ();
    int h = icon.get_height ();
    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, w, h);
    var cr = new Cairo.Context (cst);

    cr.set_source_rgba (0, 0, 0, 0);
    cr.rectangle (0, 0, w, h);
    cr.fill ();

    Gdk.cairo_set_source_pixbuf (cr, icon, 0, 0);
    Utils.cairo_rounded_box (cr,
			     0, 0,
			     w, h, 4);
    cr.fill ();

    return Gdk.pixbuf_get_from_surface (cst, 0, 0, w, h);
  }

  private static Gdk.Pixbuf? fallback_pixbuf_default;
  public static Gdk.Pixbuf draw_fallback_avatar (int size, Contact? contact) {
    if (size == SMALL_AVATAR_SIZE && fallback_pixbuf_default != null)
      return fallback_pixbuf_default;

    Gdk.Pixbuf pixbuf = null;
    try {
      var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
      var cr = new Cairo.Context (cst);

      var pat = new Cairo.Pattern.linear (0, 0, 0, size);
      pat.add_color_stop_rgb (0, 0.937, 0.937, 0.937);
      pat.add_color_stop_rgb (1, 0.969, 0.969, 0.969);

      cr.set_source (pat);
      cr.paint ();

      int avatar_size = (int) (size * 0.3);
      var icon_info = IconTheme.get_default ().lookup_icon ("avatar-default-symbolic", avatar_size,
							    IconLookupFlags.GENERIC_FALLBACK);
      if (icon_info != null) {
	Gdk.cairo_set_source_pixbuf (cr, icon_info.load_icon (), (size - avatar_size) / 2, (size - avatar_size) / 2);
	cr.rectangle ((size - avatar_size) / 2, (size - avatar_size) / 2, avatar_size, avatar_size);
	cr.fill ();
      }
      pixbuf = Gdk.pixbuf_get_from_surface (cst, 0, 0, size, size);
    } catch {
    }

    if (size == SMALL_AVATAR_SIZE)
      fallback_pixbuf_default = pixbuf;

    if (pixbuf != null)
      return pixbuf;

    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
    return Gdk.pixbuf_get_from_surface (cst, 0, 0, size, size);
  }

  /* We claim something is "removable" if at least one persona is removable,
     that will typically unlink the rest. */
  public bool can_remove_personas () {
    foreach (var p in individual.personas) {
      if (p.store.can_remove_personas == MaybeBool.TRUE &&
	  !(p is Tpf.Persona)) {
	return true;
      }
    }
    return false;
  }

  public async void remove_personas () throws Folks.PersonaStoreError {
    var personas = new HashSet<Persona> ();
    foreach (var p in individual.personas) {
      if (p.store.can_remove_personas == MaybeBool.TRUE &&
	  !(p is Tpf.Persona)) {
	personas.add (p);
      }
    }
    foreach (var persona in personas)  {
      yield persona.store.remove_persona (persona);
    }
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
      persona_set.add (new FakePersona (this));

    yield store.aggregator.link_personas (persona_set);

    p = find_primary_persona ();
    if (p == null)
      throw new ContactError.NO_PRIMARY (_("Unexpected internal error: created contact was not found"));

    return p;
  }

  public Persona? find_persona_from_store (PersonaStore store) {
    foreach (var p in individual.personas) {
      if (p.store == store)
	return p;
    }
    return null;
  }

  public Gee.List<Persona> get_personas_for_display () {
    CompareDataFunc<Persona> compare_persona_by_store = (a, b) =>
    {
      Persona persona_a = (Persona *)a;
      Persona persona_b = (Persona *)b;
      var store_a = persona_a.store;
      var store_b = persona_b.store;

      if (store_a == store_b) {
	if (persona_is_google (persona_a)) {
	  /* Non-other google personas rank before others */
	  if (persona_is_google_other (persona_a) && !persona_is_google_other (persona_b))
	    return 1;
	  if (!persona_is_google_other (persona_a) && persona_is_google_other (persona_b))
	    return -1;
	}

	return 0;
      }

      if (store_a.is_primary_store && store_b.is_primary_store)
	return 0;
      if (store_a.is_primary_store)
	return -1;
      if (store_b.is_primary_store)
	return 1;

      if (store_a.type_id == "eds" && store_b.type_id == "eds")
	return strcmp (store_a.id, store_b.id);
      if (store_a.type_id == "eds")
	return -1;
      if (store_b.type_id == "eds")
	return 1;

      return strcmp (store_a.id, store_b.id);
    };

    var persona_list = new ArrayList<Persona>();
    int i = 0;
    persona_list.add_all (individual.personas);
    while (i < persona_list.size) {
      if (persona_list[i].store.type_id == "key-file")
	persona_list.remove_at (i);
      else
	i++;
    }
    persona_list.sort ((owned) compare_persona_by_store);

    return persona_list;
  }

  public Persona? find_primary_persona () {
    if (store.aggregator.primary_store == null)
      return null;
    return find_persona_from_store (store.aggregator.primary_store);
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
      unowned string? eds_name = lookup_esource_name_by_uid (store.id);
      if (eds_name != null)
	return eds_name;
    }
    if (store.type_id == "telepathy") {
      var account = (store as Tpf.PersonaStore).account;
      return format_im_service (account.service, null);
    }

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
    var store = persona.store;

    if (store.type_id == "eds" && esource_uid_is_google (store.id))
      return true;
    return false;
  }

  /**
   * Return true only for personas which are in a Google address book, but which
   * are not in the user's "My Contacts" group in the address book.
   */
  public static bool persona_is_google_other (Persona persona) {
    if (!persona_is_google (persona))
      return false;

    var p = persona as Edsf.Persona;
    if (p != null)
      return !p.in_google_personal_group;
    return false;
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

      unowned string? eds_name = lookup_esource_name_by_uid_for_contact (store.id);
      if (eds_name != null)
	return eds_name;
    }
    if (store.type_id == "telepathy") {
      var account = (store as Tpf.PersonaStore).account;
      return format_im_service (account.service, null);
    }

    return store.display_name;
  }

  public static string[] sorted_properties = { "email-addresses" , "phone-numbers" , "im-addresses", "urls", "nickname", "birthday", "notes", "postal-addresses" };

  public static string []sort_persona_properties (string [] props) {
    CompareDataFunc<string> compare_properties = (a, b) =>
    {
      var sorted_map = new HashMap<string, int> ();
      int i = 0;
      foreach (var p in sorted_properties) {
	sorted_map.set (p, ++i);
      }

      string a_str = (string) a;
      string b_str = (string) b;

      if (sorted_map.has_key (a_str) && sorted_map.has_key (b_str)) {
	if (sorted_map[a_str] < sorted_map[b_str])
	  return -1;
	if (sorted_map[a_str] > sorted_map[b_str])
	  return 1;
	return 0;
      } else if (sorted_map.has_key (a_str))
	return -1;
      else if (sorted_map.has_key (b_str))
	return 1;
      else {
	if (a_str < b_str)
	  return -1;
      if (a_str > b_str)
	return 1;
      return 0;
      }
    };

    var sorted_props = new ArrayList<string> ();
    foreach (var s in props) {
      sorted_props.add (s);
    }
    sorted_props.sort ((owned) compare_properties);
    return sorted_props.to_array ();

  }

  /* Tries to set the property on all persons that have it writeable, and
   * if none, creates a new persona and writes to it, returning the new
   * persona.
   */
  public static async Persona? set_individual_property (Contact contact,
							string property_name,
							Value value) throws GLib.Error, PropertyError {
    bool did_set = false;
    // Need to make a copy here as it could change during the yields
    var personas_copy = contact.individual.personas.to_array ();
    foreach (var p in personas_copy) {
      if (property_name in p.writeable_properties) {
	did_set = true;
	yield Contact.set_persona_property (p, property_name, value);
      }
    }

    if (!did_set) {
      var fake = new FakePersona (contact);
      return yield fake.make_real_and_set (property_name, value);
    }
    return null;
  }

  public static async Persona? create_primary_persona_for_details (Folks.PersonaStore store, HashTable<string, Value?> details) throws GLib.Error {
    var p = yield store.add_persona_from_details (details);
    return p;
  }

  internal static async void set_persona_property (Persona persona,
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

  public void fetch_contact_info () {
    /* TODO: Ideally Folks should have API for this (#675131) */
    foreach (var p in individual.personas) {
      var tp = p as Tpf.Persona;
      if (tp != null) {
        tp.contact.request_contact_info_async.begin (null);
      }
    }
  }
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

  public static FakePersona? maybe_create_for (Contact contact) {
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

    return new FakePersona (contact);
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
	p.set ("full-name", contact.display_name);
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

  public FakePersona (Contact contact) {
    Object (display_id: "display_id",
	    uid: "uid-fake-persona",
	    iid: "iid",
	    store: contact.store.aggregator.primary_store ?? FakePersonaStore.the_store(),
	    is_user: false);
    this.contact = contact;
    this.contact.fake_persona = this;
  }
}
