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

public class Contacts.ContactPresence : Grid {
  Contact contact;
  Image image;
  Label label;
  string last_class;

  private void update_presence_widgets (Image image, Label label) {
    PresenceType type;
    string message;
    bool is_phone;

    type = contact.presence_type;
    message = contact.presence_message;
    is_phone = contact.is_phone;

    if (type == PresenceType.UNSET) {
      image.clear ();
      image.hide ();
      label.hide ();
      label.set_text ("");
      return;
    }

    image.set_from_icon_name (Contact.presence_to_icon_full (type), IconSize.MENU);
    if (last_class != null)
      image.get_style_context ().remove_class (last_class);
    last_class = Contact.presence_to_class (type);
    image.get_style_context ().add_class (last_class);
    image.show ();
    label.show ();
    if (message.length == 0)
      message = Contact.presence_to_string (type);

    if (is_phone) {
      label.set_markup (GLib.Markup.escape_text (message) + " <span color='#8e9192'>(via phone)</span>");
    } else
      label.set_text (message);
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

    update_presence_widgets (image, label);

    var id = contact.changed.connect ( () => {
	update_presence_widgets (image, label);
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

  static Gdk.Pixbuf fallback_avatar;

  public Individual individual;
  uint changed_id;

  private Gdk.Pixbuf? _avatar;
  public Gdk.Pixbuf avatar {
    get {
      if (_avatar == null)
	_avatar = frame_icon (load_icon (individual.avatar));
      return _avatar;
    }
  }

  public string display_name {
    get {
      unowned string? name = individual.full_name;
      if (name != null && name.length > 0)
	return name;
      unowned string? alias = individual.alias;
      if (alias != null && alias.length > 0)
	return individual.alias;
      foreach (var email in individual.email_addresses) {
	string? e = email.value;
	if (e != null && e.length > 0)
	  return email.value;
      }
      return "";
    }
  }

  private string filter_data;

  public signal void changed ();

  public static Contact from_individual (Individual i) {
    return i.get_data ("contact");
  }

  static construct {
    fallback_avatar = draw_fallback_avatar (48);
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

  public Contact (Store store, Individual i) {
    this.store = store;
    individual = i;
    individual.set_data ("contact", this);

    foreach (var p in individual.personas)
      connect_persona (p);

    individual.personas_changed.connect ( (added, removed) => {
	foreach (var p in added)
	  connect_persona (p);
	foreach (var p in removed)
	  disconnect_persona (p);
      });

    update ();

    individual.notify.connect(notify_cb);
  }

  public void remove () {
    unqueue_changed ();
    foreach (var p in individual.personas) {
      disconnect_persona (p);
    }
    individual.notify.disconnect(notify_cb);
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

  static string? get_first_string (Collection<string> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
  }

  private static int sort_fields_helper (FieldDetails a, FieldDetails b) {
    // TODO: This should sort firt by type and then by value
    return GLib.strcmp (a.value, b.value);
  }

  public static GLib.List<FieldDetails> sort_fields (Set<FieldDetails> details) {
    GLib.List<FieldDetails> pref = null;
    GLib.List<FieldDetails> rest = null;
    foreach (var detail in details) {
      if (get_first_string (detail.parameters.get ("x-evolution-ui-slot")) == "1") {
	pref.prepend (detail);
      } else {
	bool found = false;
	foreach (var param in detail.parameters.get ("type")) {
	  if (param.ascii_casecmp ("PREF") == 0) {
	    found = true;
	    break;
	  }
	}
	if (found)
	  pref.prepend (detail);
	else
	  rest.prepend (detail);
      }
    }
    // First all pref items, then the rest, each list sorted
    pref.sort (sort_fields_helper);
    rest.sort (sort_fields_helper);
    pref.concat ((owned)rest);
    return pref;
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

  private enum ImDisplay {
    DEFAULT,           /* $id ($service) */
    ALIAS_SERVICE      /* $alias ($service) */
  }

  private struct ImData {
    unowned string service;
    unowned string display_name;
    ImDisplay display;
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
	switch (d.display) {
	default:
	case ImDisplay.DEFAULT:
	  return id + " (" + dgettext (Config.GETTEXT_PACKAGE, d.display_name) + ")";
	case ImDisplay.ALIAS_SERVICE:
	  return persona.alias + " (" + dgettext (Config.GETTEXT_PACKAGE, d.display_name) + ")";
	}
      }
    }

    return id + " (" + protocol + ")";
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
      _avatar = null;
    queue_changed ();
  }

  private static bool get_is_phone (Persona persona) {
    var tp = persona as Tpf.Persona;
    if (tp == null || tp.contact == null)
      return false;

    var types = tp.contact.get_client_types ();

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
    foreach (string addr in im_addresses.get_values ()) {
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
  private Gdk.Pixbuf load_icon (File ?file) {
    Gdk.Pixbuf? res = fallback_avatar;
    if (file != null) {
      try {
	var stream = file.read ();
	Cancellable c = new Cancellable ();
	res = new Gdk.Pixbuf.from_stream_at_scale (stream, 48, 48, true, c);
      } catch (Error e) {
      }
    }
    return res;
  }

  private static void cairo_ellipsis (Cairo.Context cr,
				      double xc, double yc,
				      double xradius, double yradius,
				      double angle1 ,double angle2) {
    if (xradius <= 0.0 || yradius <= 0.0) {
      cr.line_to (xc, yc);
      return;
    }

    cr.save ();
    cr.translate (xc, yc);
    cr.scale (xradius, yradius);
    cr.arc (0, 0, 1.0, angle1, angle2);
    cr.restore ();
  }

  private static void rounded_box_path (Cairo.Context cr,
					int x, int y,
					int width, int height,
					int radius) {
    cr.new_sub_path ();

    cairo_ellipsis (cr,
		    x + radius,
		    y + radius,
		    radius,
		    radius,
		    Math.PI, 3 * Math.PI / 2);
    cairo_ellipsis (cr,
		    x + width - radius,
		    y + radius,
		    radius,
		    radius,
		    - Math.PI / 2, 0);
    cairo_ellipsis (cr,
		    x + width - radius,
		    y + height - radius,
		    radius,
		    radius,
		    0, Math.PI / 2);
    cairo_ellipsis (cr,
		    x + radius,
		    y + height - radius,
		    radius,
		    radius,
		    Math.PI / 2, Math.PI);
  }

  private static Gdk.Pixbuf frame_icon (Gdk.Pixbuf icon) {
    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, 52, 52);
    var cr = new Cairo.Context (cst);

    cr.set_source_rgba (0, 0, 0, 0);
    cr.rectangle (0, 0, 52, 52);
    cr.fill ();

    Gdk.cairo_set_source_pixbuf (cr, icon, 2, 2);
    cr.paint();

    rounded_box_path (cr,
		      0, 0,
		      52, 52, 5);
    rounded_box_path (cr,
		      2, 2,
		      48, 48, 3);
    cr.set_source_rgb (0.533333, 0.541176, 0.521568);
    cr.set_fill_rule (Cairo.FillRule.EVEN_ODD);

    cr.fill ();

    return Gdk.pixbuf_get_from_surface (cst, 0, 0, 52, 52);
  }

  public static Gdk.Pixbuf draw_fallback_avatar (int size) {
    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
    var cr = new Cairo.Context (cst);

    try {
      var icon_info = IconTheme.get_default ().lookup_icon ("avatar-default", size, IconLookupFlags.GENERIC_FALLBACK);
      var image = icon_info.load_icon ();
      if (image != null) {
	Gdk.cairo_set_source_pixbuf (cr, image, 0, 0);
	cr.paint();
      }
    } catch {
    }

    return Gdk.pixbuf_get_from_surface (cst, 0, 0, size, size);
  }

  public static string format_uri_link_text (FieldDetails detail) {
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

}
