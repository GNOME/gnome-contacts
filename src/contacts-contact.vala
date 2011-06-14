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

public class Contacts.Contact : GLib.Object  {
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
    fallback_avatar = draw_fallback_avatar ();
  }

  public Contact(Individual i) {
    individual = i;
    individual.set_data ("contact", this);
    update ();

    individual.notify.connect(notify_cb);
  }

  public void remove () {
    unqueue_changed ();
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

  static string? get_first_string (Collection<string> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
  }

  static int get_first_string_as_int (Collection<string> collection) {
    var s = get_first_string (collection);
    if (s == null)
      return int.MAX;
    return int.parse (s);
  }

  private struct PhoneData {
    unowned string display_name;
    unowned string types[2];
  }

  private static HashTable<unowned string, GLib.List> phone_types_hash;
  public static string format_phone_type (FieldDetails detail) {
    // List most specific first, always in upper case
    const PhoneData[] data = {
      { N_("Assistant"), { "X-EVOLUTION-ASSISTANT" } },
      { N_("Work"), { "WORK", "VOICE" } },
      // { N_("Business Phone 2"), { "WORK", "VOICE"},  1
      { N_("Work Fax"), { "WORK", "FAX" } },
      { N_("Callback"),   { "X-EVOLUTION-CALLBACK" } },
      { N_("Car"),        { "CAR" } },
      { N_("Company"),    { "X-EVOLUTION-COMPANY" } },
      { N_("Home"),       { "HOME", "VOICE" } },
      //{ N_("Home 2"),     { "HOME", "VOICE" } },  1),
      { N_("Home Fax"),         { "HOME", "FAX" } },
      { N_("ISDN"),             { "ISDN" } },
      { N_("Mobile"),     { "CELL" } },
      { N_("Other"),      { "VOICE" } },
      { N_("Fax"),        { "FAX" } },
      { N_("Pager"),            { "PAGER" } },
      { N_("Radio"),            { "X-EVOLUTION-RADIO" } },
      { N_("Telex"),            { "X-EVOLUTION-TELEX" } },
      /* To translators: TTY is Teletypewriter */
      { N_("TTY"),              { "X-EVOLUTION-TTYTDD" } },
      { N_("Home"), { "HOME" } },
      { N_("Work"), { "WORK" } }
    };
    if (detail.parameters.contains ("x-google-label")) {
      return get_first_string (detail.parameters.get ("x-google-label"));
    }
    if (phone_types_hash == null) {
      phone_types_hash = new HashTable<unowned string, GLib.List<PhoneData*> > (str_hash, str_equal);
      for (int i = 0; i < data.length; i++) {
	PhoneData *d = &data[i];
	unowned GLib.List<PhoneData *> l = phone_types_hash.lookup (d.types[0]);
	if (l != null) {
	  l.append (d);
	} else {
	  GLib.List<PhoneData *> l2 = null;
	  l2.append (d);
	  phone_types_hash.insert (d.types[0], (owned) l2);
	}
      }
    }

    var i = detail.get_parameter_values ("type");
    if (i == null || i.is_empty)
      return _("Other");

    var list = new Gee.ArrayList<string> ();
    foreach (var s in detail.get_parameter_values ("type")) {
      if (s.ascii_casecmp ("OTHER") == 0 ||
	  s.ascii_casecmp ("PREF") == 0)
	continue;
      list.add (s.up ());
    }

    if (list.is_empty)
      return _("Other");

    list.sort ();

    unowned GLib.List<PhoneData *>? l = phone_types_hash.lookup (list[0]);
    foreach (var d in l) {
      bool all_found = true;
      for (int j = 0; j < 2 && d.types[j] != null; j++) {
	if (!list.contains (d.types[j])) {
	  all_found = false;
	  break;
	}
      }
      if (all_found)
	return dgettext (Config.GETTEXT_PACKAGE, d.display_name);
    }

    return _("Other");
  }

  private struct EmailData {
    unowned string display_name;
    unowned string types[2];
  }

  private static HashTable<unowned string, GLib.List> email_types_hash;
  public static string format_email_type (FieldDetails detail) {
    // List most specific first, always in upper case
    const EmailData[] data = {
      { N_("Home"), { "HOME" } },
      { N_("Work"), { "WORK" } }
    };
    if (detail.parameters.contains ("x-google-label")) {
      return get_first_string (detail.parameters.get ("x-google-label"));
    }
    if (email_types_hash == null) {
      email_types_hash = new HashTable<unowned string, GLib.List<EmailData*> > (str_hash, str_equal);
      for (int i = 0; i < data.length; i++) {
	EmailData *d = &data[i];
	unowned GLib.List<EmailData *> l = email_types_hash.lookup (d.types[0]);
	if (l != null) {
	  l.append (d);
	} else {
	  GLib.List<EmailData *> l2 = null;
	  l2.append (d);
	  email_types_hash.insert (d.types[0], (owned) l2);
	}
      }
    }

    var i = detail.get_parameter_values ("type");
    if (i == null || i.is_empty)
      return _("Other");

    var list = new Gee.ArrayList<string> ();
    foreach (var s in detail.get_parameter_values ("type")) {
      if (s.ascii_casecmp ("OTHER") == 0 ||
	  s.ascii_casecmp ("INTERNET") == 0 ||
	  s.ascii_casecmp ("PREF") == 0)
	continue;
      list.add (s.up ());
    }

    if (list.is_empty)
      return _("Other");

    list.sort ();

    unowned GLib.List<EmailData *>? l = email_types_hash.lookup (list[0]);
    foreach (var d in l) {
      bool all_found = true;
      for (int j = 0; j < 2 && d.types[j] != null; j++) {
	if (!list.contains (d.types[j])) {
	  all_found = false;
	  break;
	}
      }
      if (all_found)
	return dgettext (Config.GETTEXT_PACKAGE, d.display_name);
    }

    return _("Other");
  }

  public static GLib.List<FieldDetails> sort_fields (Set<FieldDetails> details) {
    GLib.List<FieldDetails> sorted = null;
    GLib.List<FieldDetails> pref = null;
    GLib.List<FieldDetails> rest = null;
    foreach (var detail in details) {
      if (detail.parameters.contains ("x-evolution-ui-slot")) {
	sorted.prepend (detail);
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
    pref.reverse();
    rest.reverse();
    sorted.sort ( (a, b) => {
	var aa = get_first_string_as_int (a.parameters.get ("x-evolution-ui-slot"));
	var bb = get_first_string_as_int (b.parameters.get ("x-evolution-ui-slot"));
	return aa - bb;
      });
    sorted.concat ((owned)pref);
    sorted.concat ((owned)rest);
    return sorted;
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
      { "localxmpp", N_("Local network")},
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

  private void update_presence_widgets (Image image, Label label) {
    if (individual.presence_type == PresenceType.UNSET) {
      image.clear ();
      image.hide ();
      label.hide ();
      label.set_text ("");
      return;
    }

    image.set_from_icon_name (presence_to_icon_full (individual.presence_type), IconSize.MENU);
    image.show ();
    label.show ();
    if (individual.presence_message == null ||
	individual.presence_message.length == 0) {
      label.set_text (presence_to_string (individual.presence_type));
    } else {
      label.set_text (individual.presence_message);
    }
  }

  public Widget? create_merged_presence_widget () {
    var grid = new Grid ();
    grid.set_row_spacing (4);
    var image = new Image ();
    image.set_no_show_all (true);
    grid.add (image);
    var label = new Label ("");
    label.set_no_show_all (true);
    grid.add (label);


    update_presence_widgets (image, label);

    var id1 = individual.notify["presence-type"].connect ((pspec) => {
	update_presence_widgets (image, label);
     });

    var id2 = individual.notify["presence-message"].connect ( (pspec) => {
	update_presence_widgets (image, label);
      });

    grid.destroy.connect (() => {
	individual.disconnect(id1);
	individual.disconnect(id2);
      });

    return grid;
  }

  public Widget? create_presence_widget (string protocol, string im_address) {
    var tp = find_im_persona (protocol, im_address);
    if (tp == null)
      return null;

    var i = new Image ();
    i.set_from_icon_name (presence_to_icon_full (tp.presence_type), IconSize.MENU);
    i.set_tooltip_text (tp.presence_message);

    var id1 = tp.notify["presence-type"].connect ((pspec) => {
      i.set_from_icon_name (presence_to_icon_full (tp.presence_type), IconSize.MENU);
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

  private void update () {
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

  private static void round_rect (Cairo.Context cr, int x, int y, int w, int h, int r) {
    cr.move_to(x+r,y);
    cr.line_to(x+w-r,y);
    cr.curve_to(x+w,y,x+w,y,x+w,y+r);
    cr.line_to(x+w,y+h-r);
    cr.curve_to(x+w,y+h,x+w,y+h,x+w-r,y+h);
    cr.line_to(x+r,y+h);
    cr.curve_to(x,y+h,x,y+h,x,y+h-r);
    cr.line_to(x,y+r);
    cr.curve_to(x,y,x,y,x+r,y);
  }

  private static Gdk.Pixbuf frame_icon (Gdk.Pixbuf icon) {
    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, 52, 52);
    var cr = new Cairo.Context (cst);

    cr.set_source_rgba (0, 0, 0, 0);
    cr.rectangle (0, 0, 52, 52);
    cr.fill ();

    round_rect (cr, 0, 0, 52, 52, 5);
    cr.set_source_rgb (0.74117, 0.74117, 0.74117);
    cr.fill ();

    round_rect (cr, 1, 1, 50, 50, 5);
    cr.set_source_rgb (1, 1, 1);
    cr.fill ();

    Gdk.cairo_set_source_pixbuf (cr, icon, 2, 2);
    cr.paint();

    return Gdk.pixbuf_get_from_surface (cst, 0, 0, 52, 52);
  }

  private static Gdk.Pixbuf draw_fallback_avatar () {
    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, 48, 48);
    var cr = new Cairo.Context (cst);

    try {
      var icon_info = IconTheme.get_default ().lookup_icon ("avatar-default", 48, IconLookupFlags.GENERIC_FALLBACK);
      var image = icon_info.load_icon ();
      if (image != null) {
	Gdk.cairo_set_source_pixbuf (cr, image, 0, 0);
	cr.paint();
      }
    } catch {
    }

    return Gdk.pixbuf_get_from_surface (cst, 0, 0, 48, 48);
  }
}
