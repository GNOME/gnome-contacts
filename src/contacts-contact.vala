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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

using Gtk;
using Folks;
using Gee;

public errordomain ContactError {
  NOT_IMPLEMENTED,
  NO_PRIMARY
}

public class Contacts.ContactPresence : Grid {
  Contact contact;
  Image image;
  Image phone_image;
  Label label;
  string last_class;

  private void update_presence_widgets () {
    PresenceType type;
    string message;
    bool is_phone;

    type = contact.presence_type;
    message = contact.presence_message;
    is_phone = contact.is_phone;

    if (type == PresenceType.UNSET ||
        type == PresenceType.ERROR ||
        type == PresenceType.OFFLINE) {
      image.clear ();
      image.hide ();
      label.hide ();
      label.set_text ("");
      phone_image.hide ();
      return;
    }

    image.set_from_icon_name (Contact.presence_to_icon_full (type), IconSize.MENU);
    if (last_class != null)
      image.get_style_context ().remove_class (last_class);
    last_class = Contact.presence_to_class (type);
    image.get_style_context ().add_class (last_class);
    image.show ();
    label.show ();
    phone_image.show ();
    if (message.length == 0)
      message = Contact.presence_to_string (type);

    label.set_text (message);

    if (is_phone)
      phone_image.show ();
    else
      phone_image.hide ();
  }

  public ContactPresence (Contact contact) {
    this.contact = contact;

    this.set_row_spacing (4);
    image = new Image ();
    image.set_no_show_all (true);
    this.add (image);
    label = new Label ("");
    label.set_no_show_all (true);
    label.set_ellipsize (Pango.EllipsizeMode.END);
    label.xalign = 0.0f;

    this.add (label);

    phone_image = new Image ();
    phone_image.set_no_show_all (true);
    phone_image.set_from_icon_name ("phone-symbolic", IconSize.MENU);
    this.add (phone_image);

    update_presence_widgets ();

    var id = contact.changed.connect ( () => {
	update_presence_widgets ();
      });

    this.destroy.connect (() => {
	contact.disconnect (id);
      });
  }
}


public class Contacts.Contact : GLib.Object  {
  public Store store;
  public PresenceType presence_type;
  public string presence_message;
  public bool is_phone;
  struct ContactDataRef {
    void *key;
    void *data;
  }
  private ContactDataRef[] refs;

  public Individual individual;
  uint changed_id;

  private Gdk.Pixbuf? _small_avatar;
  public Gdk.Pixbuf small_avatar {
    get {
      if (_small_avatar == null) {
	var pixbuf = load_icon (individual.avatar, 48);
	if (pixbuf == null)
	  pixbuf = draw_fallback_avatar (48, this);
	_small_avatar = frame_icon (pixbuf);
      }
      return _small_avatar;
    }
  }

  public string display_name {
    get {
      unowned string? name = individual.full_name;
      if (name != null && name.length > 0)
	return name;
      unowned string? alias = individual.alias;
      if (alias != null && alias.length > 0)
	return alias;
      unowned string? nickname = individual.nickname;
      if (nickname != null && nickname.length > 0)
	return nickname;
      foreach (var email in individual.email_addresses) {
	string? e = email.value;
	if (e != null && e.length > 0)
	  return email.value;
      }
      return "";
    }
  }

  public static string get_display_name_for_persona (Persona persona) {
    var name_details = persona as NameDetails;
    var alias_details = persona as AliasDetails;
    var email_details = persona as EmailDetails;

    if (name_details != null) {
      unowned string? name = name_details.full_name;
      if (name != null && name.length > 0)
	return name;
    }
    if (alias_details != null) {
      unowned string? alias = alias_details.alias;
      if (alias != null && alias.length > 0)
	return alias;
    }
    if (name_details != null) {
      unowned string? nickname = name_details.nickname;
      if (nickname != null && nickname.length > 0)
	return nickname;
    }
    if (email_details != null) {
      foreach (var email in email_details.email_addresses) {
	string e = email.value;
	if (e != null && e.length > 0)
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

  public bool is_hidden () {
    // Don't show the user itself
    if (individual.is_user)
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

  public static Contact from_individual (Individual i) {
    return i.get_data ("contact");
  }

  private void persona_notify_cb (ParamSpec pspec) {
    queue_changed ();
  }

  private void connect_persona (Persona p) {
    p.notify["presence-type"].connect (persona_notify_cb);
    p.notify["presence-message"].connect (persona_notify_cb);
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

  public unowned T lookup<T> (void *key) {
    foreach (unowned ContactDataRef? data_ref in refs) {
      if (data_ref.key == key)
	return (T*)data_ref.data;
    }
    return null;
  }

  public void set_lookup<T> (void *key, owned T data) {
    int i = refs.length;
    refs.resize(i+1);
    refs[i].key = key;
    refs[i].data = (void *)(owned)data;
  }

  public void remove_lookup<T> (void *key) {
    int i;

    for (i = 0; i < refs.length; i++) {
      if (refs[i].key == key) {
	T old_val = (owned)refs[i].data;
	for (int j = i + 1; j < refs.length; j++) {
	  refs[j-1] = refs[j];
	}
	refs.resize(refs.length-1);
	return;
      }
    }
  }

  public Contact (Store store, Individual i) {
    this.store = store;
    individual = i;
    individual.set_data ("contact", this);
    this.refs = new ContactDataRef[0];

    foreach (var p in individual.personas)
      connect_persona (p);

    individual.personas_changed.connect ( (added, removed) => {
	foreach (var p in added)
	  connect_persona (p);
	foreach (var p in removed)
	  disconnect_persona (p);
	queue_changed ();
      });

    update ();

    individual.notify.connect(notify_cb);
  }

  public void replace_individual (Individual new_individual) {
    foreach (var p in individual.personas) {
      disconnect_persona (p);
    }
    individual = new_individual;
    individual.set_data ("contact", this);
    foreach (var p in individual.personas) {
      connect_persona (p);
    }
    queue_changed ();
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

  public bool contains_strings (string [] strings) {
    foreach (string i in strings) {
      if (! (i in filter_data))
	return false;
    }
    return true;
  }

  public static string presence_to_string (PresenceType presence) {
    switch (presence) {
    default:
    case PresenceType.UNKNOWN:
      return _("Unknown status");
    case PresenceType.OFFLINE:
      return _("Offline");
    case PresenceType.UNSET:
      return "";
    case PresenceType.ERROR:
      return _("Error");
    case PresenceType.AVAILABLE:
      return _("Available");
    case PresenceType.AWAY:
      return _("Away");
    case PresenceType.EXTENDED_AWAY:
      return _("Extended away");
    case PresenceType.BUSY:
      return _("Busy");
    case PresenceType.HIDDEN:
      return _("Hidden");
    }
  }

  public static string presence_to_icon (PresenceType presence) {
    string? iconname = null;
    switch (presence) {
    default:
    case PresenceType.OFFLINE:
    case PresenceType.UNSET:
    case PresenceType.ERROR:
      break;
    case PresenceType.AVAILABLE:
    case PresenceType.UNKNOWN:
      iconname = "user-available-symbolic";
      break;
    case PresenceType.AWAY:
    case PresenceType.EXTENDED_AWAY:
      iconname = "user-away-symbolic";
      break;
    case PresenceType.BUSY:
      iconname = "user-busy-symbolic";
      break;
    case PresenceType.HIDDEN:
      iconname = "user-invisible-symbolic";
      break;
    }
    return iconname;
  }

  public static string presence_to_icon_full (PresenceType presence) {
    string? iconname = presence_to_icon (presence);
    if (iconname != null)
      return iconname;
    return "user-offline-symbolic";
  }

  public static string presence_to_class (PresenceType presence) {
    string? classname = null;
    switch (presence) {
    default:
    case PresenceType.HIDDEN:
    case PresenceType.OFFLINE:
    case PresenceType.UNSET:
    case PresenceType.ERROR:
      classname = "presence-icon-offline";
      break;
    case PresenceType.AVAILABLE:
    case PresenceType.UNKNOWN:
      classname = "presence-icon-available";
      break;
    case PresenceType.AWAY:
    case PresenceType.EXTENDED_AWAY:
      classname = "presence-icon-away";
      break;
    case PresenceType.BUSY:
      classname = "presence-icon-busy";
      break;
    }
    return classname;
  }

  static string? get_first_string (Collection<string>? collection) {
    if (collection != null) {
      var i = collection.iterator();
      if (i.next())
	return i.get();
    }
    return null;
  }

  private static bool has_pref (AbstractFieldDetails details) {
    if (get_first_string (details.get_parameter_values ("x-evolution-ui-slot")) == "1")
      return true;
    foreach (var param in details.parameters.get ("type")) {
      if (param.ascii_casecmp ("PREF") == 0)
	return true;
    }
    return false;
  }

  public static int compare_fields (void *a, void *b) {
    AbstractFieldDetails *details_a = (AbstractFieldDetails *)a;
    AbstractFieldDetails *details_b = (AbstractFieldDetails *)b;
    bool first_a = has_pref (details_a);
    bool first_b = has_pref (details_b);

    if (first_a == first_b)
      return 0;
    if (first_a)
      return -1;
    return 1;
  }

  public static ArrayList<T> sort_fields<T> (Collection<T> fields) {
    // TODO: This should take an extra delegate arg to compare by value for T
    var res = new ArrayList<T>();
    res.add_all (fields);
    res.sort (Contact.compare_fields);
    return res;
  }

  public static string[] format_address (PostalAddress addr) {
    string[] lines = {};
    string str;

    str = addr.street;
    if (str != null && str.length > 0)
      lines += str;

    str = addr.extension;
    if (str != null && str.length > 0)
      lines += str;

    str = addr.locality;
    if (str != null && str.length > 0)
      lines += str;

    str = addr.region;
    if (str != null && str.length > 0)
      lines += str;

    str = addr.postal_code;
    if (str != null && str.length > 0)
      lines += str;

    str = addr.po_box;
    if (str != null && str.length > 0)
      lines += str;

    str = addr.country;
    if (str != null && str.length > 0)
      lines += str;

    str = addr.address_format;
    if (str != null && str.length > 0)
      lines += str;

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

  public string format_im_name (string protocol, string id) {
    string? service = null;
    var persona = find_im_persona (protocol, id);
    if (persona != null) {
      var account = (persona.store as Tpf.PersonaStore).account;
      service = account.service;
    }
    if (service == null || service == "")
      service = protocol;

    ImDisplay display;
    var display_name = format_im_service (service, out display);

    switch (display) {
    default:
    case ImDisplay.DEFAULT:
      return id + " (" + display_name + ")";
    case ImDisplay.ALIAS_SERVICE:
      return persona.alias + " (" + display_name + ")";
    }
  }

  public Widget? create_merged_presence_widget () {
    return new ContactPresence (this);
  }

  public Widget? create_presence_widget (string protocol, string im_address) {
    var tp = find_im_persona (protocol, im_address);
    if (tp == null)
      return null;

    var i = new Image ();
    i.set_from_icon_name (presence_to_icon_full (tp.presence_type), IconSize.MENU);
    string last_class = Contact.presence_to_class (tp.presence_type);
    i.get_style_context ().add_class (last_class);
    i.set_tooltip_text (tp.presence_message);

    var id1 = tp.notify["presence-type"].connect ((pspec) => {
      i.set_from_icon_name (presence_to_icon_full (tp.presence_type), IconSize.MENU);
      i.get_style_context ().remove_class (last_class);
      last_class = Contact.presence_to_class (tp.presence_type);
      i.get_style_context ().add_class (last_class);
     });
    var id2 = tp.notify["presence-message"].connect ( (pspec) => {
	i.set_tooltip_text (tp.presence_message);
      });
    i.destroy.connect (() => {
	tp.disconnect(id1);
	tp.disconnect(id2);
      });
    return i;
  }

  private bool changed_cb () {
    changed_id = 0;
    update ();
    changed ();
    return false;
  }

  private void unqueue_changed () {
    if (changed_id != 0) {
      Source.remove (changed_id);
      changed_id = 0;
    }
  }

  private void queue_changed () {
    if (changed_id != 0)
      return;

    changed_id = Idle.add (changed_cb);
  }

  private void notify_cb (ParamSpec pspec) {
    if (pspec.get_name () == "avatar")
      _small_avatar = null;
    queue_changed ();
  }

  private static bool get_is_phone (Persona persona) {
    var tp = persona as Tpf.Persona;
    if (tp == null || tp.contact == null)
      return false;

    var types = tp.contact.client_types;

    return (types != null && types[0] == "phone");
  }

  private void update_presence () {
    presence_message = null;
    presence_type = Folks.PresenceType.UNSET;
    is_phone = false;

    /* Choose the most available presence from our personas */
    foreach (var p in individual.personas) {
      if (p is PresenceDetails) {
	unowned PresenceDetails presence = (PresenceDetails) p;
	var p_is_phone = get_is_phone (p);
	if (PresenceDetails.typecmp (presence.presence_type,
				     presence_type) > 0 ||
	    (presence.presence_type == presence_type &&
	     is_phone && !p_is_phone)) {
	  presence_type = presence.presence_type;
	  presence_message = presence.presence_message;
	  is_phone = p_is_phone;
	}
      }
    }

    if (presence_message == null)
      presence_message = "";
  }

  private void update_filter_data () {
    var builder = new StringBuilder ();
    if (individual.alias != null) {
      builder.append (individual.alias.casefold ());
      builder.append_unichar (' ');
    }
    if (individual.full_name != null) {
      builder.append (individual.full_name.casefold ());
      builder.append_unichar (' ');
    }
    if (individual.nickname != null) {
      builder.append (individual.nickname.casefold ());
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
    filter_data = builder.str;
  }

  private void update () {
    foreach (var email in individual.email_addresses) {
      TypeSet.general.type_seen (email);
    }

    foreach (var phone in individual.phone_numbers) {
      TypeSet.phone.type_seen (phone);
    }

    update_presence ();
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
      } catch (Error e) {
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

  private static Gdk.Pixbuf? fallback_pixbuf_48;
  public static Gdk.Pixbuf draw_fallback_avatar (int size, Contact? contact) {
    if (size == 48 && fallback_pixbuf_48 != null)
      return fallback_pixbuf_48;

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
      Gdk.cairo_set_source_pixbuf (cr, icon_info.load_icon (), (size - avatar_size) / 2, (size - avatar_size) / 2);
      cr.rectangle ((size - avatar_size) / 2, (size - avatar_size) / 2, avatar_size, avatar_size);
      cr.fill ();
      pixbuf = Gdk.pixbuf_get_from_surface (cst, 0, 0, size, size);
    } catch {
    }

    if (size == 48)
      fallback_pixbuf_48 = pixbuf;

    if (pixbuf != null)
      return pixbuf;

    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
    return Gdk.pixbuf_get_from_surface (cst, 0, 0, size, size);
  }

  public static string format_uri_link_text (UrlFieldDetails detail) {
    // TODO: Detect link type, possibly using types parameter (to be standardized bz#653623)
    // TODO: Add more custom url matches

    string uri = detail.value;

    if (/https?:\/\/www.facebook.com\/profile\.php\?id=[0-9]+$/.match(uri) ||
	/https?:\/\/www.facebook.com\/[a-zA-Z0-9]+$/.match(uri))
      return _("Facebook");

    if (/https?:\/\/twitter.com\/#!\/[a-zA-Z0-9]+$/.match(uri))
      return _("Twitter");

    return uri;
  }

  public async Persona ensure_primary_persona () throws GLib.Error {
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
    var fake_persona = FakePersona.maybe_create_for (this);
    if (fake_persona != null)
      persona_set.add (fake_persona);

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

  public Persona? find_primary_persona () {
    return find_persona_from_store (store.aggregator.primary_store);
  }

  public static string format_persona_store_name (PersonaStore store) {
    if (store.type_id == "eds") {
      if (store.id == "system") {
	return _("Local Contact");
      }
      if (store.id.has_suffix ("@gmail.com")) {
	return _("Google");
      }
    }
    if (store.type_id == "telepathy") {
      var account = (store as Tpf.PersonaStore).account;
      return format_im_service (account.service, null);
    }

    return store.display_name;
  }
}

public class Contacts.FakePersona : Persona {
  public static FakePersona? maybe_create_for (Contact contact) {
    var primary_persona = contact.find_primary_persona ();

    if (primary_persona != null)
      return null;

    return new FakePersona (contact, contact.store.aggregator.primary_store);
  }

  private const string[] _linkable_properties = {};
  private const string[] _writeable_properties = {};
  public override string[] linkable_properties
    {
      get { return this._linkable_properties; }
    }

  public override string[] writeable_properties
    {
      get { return this._writeable_properties; }
    }

  public FakePersona (Contact contact, PersonaStore store) {
    Object (display_id: "display_id",
	    uid: "uid",
	    iid: "iid",
	    store: store,
	    is_user: false);
  }
}
