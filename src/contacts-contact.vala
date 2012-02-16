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

    label.set_markup ("<span font='11px'>" + message + "</span>");
    label.set_margin_bottom (3);

    if (is_phone)
      phone_image.show ();
    else
      phone_image.hide ();
  }

  public ContactPresence (Contact contact) {
    this.contact = contact;

    this.set_column_spacing (4);
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

    var id = contact.presence_changed.connect ( () => {
	update_presence_widgets ();
      });

    this.destroy.connect (() => {
	contact.disconnect (id);
      });
  }
}


public class Contacts.Contact : GLib.Object  {
  public const int SMALL_AVATAR_SIZE = 54;

  public Store store;
  public bool is_main;
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
  bool changed_personas;

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

  // Synchronize with get_secondary_string_source ()
  public string? get_secondary_string (out string [] sources = null) {
    var nick = individual.nickname;
    if (is_set (nick)) {
      sources = new string[1];
      sources[0] = "nickname";
      return "\xE2\x80\x9C" + nick + "\xE2\x80\x9D";
    }

    foreach (var role_detail in individual.roles) {
      var role = role_detail.value;

      if (is_set (role.organisation_name)) {
	if (is_set (role.title)) {
	  sources = new string[2];
	  sources[0] = "title";
	  sources[1] = "organisation-name";
	  return "%s, %s".printf (role.title, role.organisation_name);
	} else if (is_set (role.role)) {
	  sources = new string[2];
	  sources[0] = "role";
	  sources[1] = "organisation-name";
	  return "%s, %s".printf (role.role, role.organisation_name);
	} else {
	  sources = new string[0];
	  sources[0] = "organisation-name";
	  return role.organisation_name;
	}
      } else if (is_set (role.title)) {
	sources = new string[0];
	sources[0] = "title";
	return role.title;
      } else if (is_set (role.role)) {
	sources = new string[0];
	sources[0] = "role";
	return role.role;
      }
    }

    sources = null;
    return null;
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

  public signal void presence_changed ();
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
    this.presence_changed ();
    queue_changed (false);
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
    // Transfer ownership to the array
    refs[i].data = (void *)(owned)data;
  }

  public void remove_lookup<T> (void *key) {
    int i;

    for (i = 0; i < refs.length; i++) {
      if (refs[i].key == key) {
	// We need to unref the data so we take a local
	// owned copy and let it go out of scope
	T old_val = (owned)refs[i].data;
	// Reference the variable to avoid warning
	(void)old_val;
	for (int j = i + 1; j < refs.length; j++) {
	  refs[j-1] = refs[j];
	}
	refs.resize(refs.length-1);
	return;
      }
    }
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
    this.refs = new ContactDataRef[0];

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

  public static string presence_to_icon_symbolic (PresenceType presence) {
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

  public static string presence_to_icon_symbolic_full (PresenceType presence) {
    string? iconname = presence_to_icon_symbolic (presence);
    if (iconname != null)
      return iconname;
    return "user-offline-symbolic";
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
      iconname = "user-available";
      break;
    case PresenceType.AWAY:
    case PresenceType.EXTENDED_AWAY:
      iconname = "user-away";
      break;
    case PresenceType.BUSY:
      iconname = "user-busy";
      break;
    case PresenceType.HIDDEN:
      iconname = "user-invisible";
      break;
    }
    return iconname;
  }

  public static string presence_to_icon_full (PresenceType presence) {
    string? iconname = presence_to_icon (presence);
    if (iconname != null)
      return iconname;
    return "user-offline";
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

    if (a is EmailFieldDetails || a is PhoneFieldDetails) {
      var aa = a as AbstractFieldDetails<string>;
      var bb = b as AbstractFieldDetails<string>;
      return strcmp (aa.value, bb.value);
    }

    warning ("Unsupported AbstractFieldDetails value type");

    return 0;
  }

  public static int compare_persona_by_store (void *a, void *b) {
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
  }

  public static ArrayList<T> sort_fields<T> (Collection<T> fields) {
    var res = new ArrayList<T>();
    res.add_all (fields);
    res.sort (Contact.compare_fields);
    return res;
  }

  public static string[] postal_element_props = {"street", "extension", "locality", "region", "postal_code", "po_box", "country"};
  public static string[] postal_element_names = {_("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

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

  public static string format_im_name (Tpf.Persona? persona,
				       string protocol, string id) {
    string? service = null;
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
    var changed_personas = this.changed_personas;
    this.changed_personas = false;
    if (changed_personas) {
      this.is_main = calc_is_main ();
    }
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
    if (pspec.get_name () == "avatar")
      _small_avatar = null;
    queue_changed (false);
  }

  private static bool get_is_phone (Persona persona) {
    var tp = persona as Tpf.Persona;
    if (tp == null || tp.contact == null)
      return false;

    unowned string[] types = tp.contact.client_types;

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
      Gdk.cairo_set_source_pixbuf (cr, icon_info.load_icon (), (size - avatar_size) / 2, (size - avatar_size) / 2);
      cr.rectangle ((size - avatar_size) / 2, (size - avatar_size) / 2, avatar_size, avatar_size);
      cr.fill ();
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

  public static string format_uri_link_text (UrlFieldDetails detail) {
    // TODO: Detect link type, possibly using types parameter (to be standardized bz#653623)
    // TODO: Add more custom url matches

    string uri = detail.value;

    if (/https?:\/\/www.facebook.com\/profile\.php\?id=[0-9]+$/.match(uri) ||
	/https?:\/\/www.facebook.com\/[a-zA-Z0-9]+$/.match(uri))
      return _("Facebook");

    if (/https?:\/\/twitter.com\/#!\/[a-zA-Z0-9]+$/.match(uri))
      return _("Twitter");

    if (/https?:\/\/www.google.com\/profiles\/[0-9]+$/.match(uri))
      return _("Google Profile");

    if (uri.ascii_ncasecmp ("http:", 5) == 0 ||
	uri.ascii_ncasecmp ("https:", 5) == 0) {
      var start = uri.index_of (":");
      start++;
      while (uri[start] == '/')
	start++;
      var last = uri.index_of ("/", start);
      if (last < 0)
	last = uri.length;

      return uri[start:last];
    }

    return uri;
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

  public async void remove_personas () {
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
    var persona_list = new ArrayList<Persona>();
    int i = 0;
    persona_list.add_all (individual.personas);
    while (i < persona_list.size) {
      if (persona_list[i].store.type_id == "key-file")
	persona_list.remove_at (i);
      else
	i++;
    }
    persona_list.sort (Contact.compare_persona_by_store);

    return persona_list;
  }

  public Persona? find_primary_persona () {
    if (store.aggregator.primary_store == null)
      return null;
    return find_persona_from_store (store.aggregator.primary_store);
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

  public static PersonaStore[] get_eds_address_books () {
    PersonaStore[] stores = {};
    foreach (var backend in App.app.contacts_store.backend_store.enabled_backends.values) {
      foreach (var persona_store in backend.persona_stores.values) {
	if (persona_store.type_id == "eds") {
	  stores += persona_store;
	}
      }
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

    if (!App.app.contacts_store.may_suggest_link (this, other))
      return false;

    /* Only connect main contacts with non-mainable contacts, and vice versa. */
    if ((this.is_main && !other.has_mainable_persona()) ||
	(!this.has_mainable_persona () && other.is_main)) {
      return true;
    }
    return false;
  }

  private static bool persona_is_google (Persona persona) {
    var store = persona.store;

    if (store.type_id == "eds" && esource_uid_is_google (store.id))
      return true;
    return false;
  }

  public static bool persona_is_google_other (Persona persona) {
    if (!persona_is_google (persona))
      return false;

    var g = persona as GroupDetails;
    if (g != null && !g.groups.contains (eds_personal_google_group_name ()))
      return true;
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
	return _("Google Other Contact");

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

  public Account? is_callable (string proto, string id) {
    Tpf.Persona? t_persona = this.find_im_persona (proto, id);
    if (t_persona != null && t_persona.contact != null) {
      unowned TelepathyGLib.Capabilities caps =
      t_persona.contact.get_capabilities ();
      unowned GLib.GenericArray<ValueArray> classes =
	(GLib.GenericArray<ValueArray>) caps.get_channel_classes ();
      for (var i=0; i < classes.length; i++) {
	unowned ValueArray clazz = classes.get (i);
	if (clazz.n_values != 2)
	  continue;

	unowned Value fixed_prop_val = clazz.get_nth (0);
	unowned HashTable<string, Value?>? fixed_prop =
	  (HashTable<string, Value?>) fixed_prop_val.get_boxed ();
	unowned Value allowed_prop_val = clazz.get_nth (1);
	unowned string[]? allowed_prop = (string[]) allowed_prop_val.get_boxed ();

	if (fixed_prop == null || allowed_prop == null)
	  continue;

	var chan_type = fixed_prop.get (
	    TelepathyGLib.PROP_CHANNEL_CHANNEL_TYPE).get_string ();
	var handle_type = fixed_prop.get (
	    TelepathyGLib.PROP_CHANNEL_TARGET_HANDLE_TYPE).get_uint ();
	if (handle_type != (int) TelepathyGLib.HandleType.CONTACT)
	  continue;

	if (chan_type == TelepathyGLib.IFACE_CHANNEL_TYPE_STREAMED_MEDIA) {
	  for (uint j=0; allowed_prop[j] != null; j++) {
	    var prop = allowed_prop[j];
	    if (prop ==
		TelepathyGLib.PROP_CHANNEL_TYPE_STREAMED_MEDIA_INITIAL_AUDIO)
	      return (t_persona.store as Tpf.PersonaStore).account;
	  }
	}
      }
    }

    return null;
  }

  public static async Persona? create_primary_persona_for_details (HashTable<string, Value?> details) throws Folks.PersonaStoreError {
    var primary_store = App.app.contacts_store.aggregator.primary_store;
    return yield primary_store.add_persona_from_details (details);
  }

  internal static async void set_persona_property (Persona persona,
						   string property_name, Value new_value) throws PropertyError, IndividualAggregatorError, ContactError, PropertyError {
    if (persona is FakePersona) {
      var fake = persona as FakePersona;
      yield fake.make_real_and_set (property_name, new_value);
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

  public void keep_widget_uptodate (Widget w, Gtk.Callback callback) {
    callback(w);
    ulong id = this.changed.connect ( () => { callback(w); });
    w.destroy.connect (() => { this.disconnect (id); });
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
      get { return this._linkable_properties; }
    }

  public override string[] writeable_properties
    {
      get { return this._writeable_properties; }
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
	    uid: "uid",
	    iid: "iid",
	    store: contact.store.aggregator.primary_store ?? FakePersonaStore.the_store(),
	    is_user: false);
    this.contact = contact;
  }
}
