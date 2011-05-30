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

public class Contacts.Contact : GLib.Object  {
  static Gdk.Pixbuf fallback_avatar;

  public Individual individual;
  uint changed_id;

  private Gdk.Pixbuf? _avatar;
  public Gdk.Pixbuf avatar {
    get {
      if (_avatar == null)
	_avatar = load_icon (individual.avatar);
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

  public Persona? find_im_persona (string protocol, string im_address) {
    foreach (var p in individual.personas) {
      var iid = protocol + ":" + im_address;
      var tp = p as Tpf.Persona;
      if (tp != null && tp.iid == iid) {
	return p;
      }
    }
    return null;
  }

  public Widget? create_presence_widget (string protocol, string im_address) {
    var tp = find_im_persona (protocol, im_address);
    if (tp == null)
      return null;

    var presence_details = tp as PresenceDetails;
    if (presence_details == null)
      return null;

    var i = new Image ();
    i.set_from_icon_name (presence_to_icon (presence_details.presence_type), IconSize.BUTTON);
    i.set_tooltip_text (presence_details.presence_message);

    var id1 = tp.notify["presence-type"].connect ((pspec) => {
      i.set_from_icon_name (presence_to_icon (presence_details.presence_type), IconSize.BUTTON);
     });
    var id2 = tp.notify["presence-message"].connect ( (pspec) => {
	i.set_tooltip_text (presence_details.presence_message);
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

  private static Gdk.Pixbuf draw_fallback_avatar () {
    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, 48, 48);
    var cr = new Cairo.Context (cst);

    cr.save ();

    var gradient = new Cairo.Pattern.linear (1,  1, 1, 1+48);
    gradient.add_color_stop_rgb (0, 0.7098, 0.7098, 0.7098);
    gradient.add_color_stop_rgb (1, 0.8901, 0.8901, 0.8901);
    cr.set_source (gradient);
    cr.rectangle (1, 1, 46, 46);
    cr.fill ();

    cr.restore ();

    try {
      var icon_info = IconTheme.get_default ().lookup_icon ("avatar-default", 48, IconLookupFlags.GENERIC_FALLBACK);
      var image = icon_info.load_icon ();
      if (image != null) {
	Gdk.cairo_set_source_pixbuf (cr, image, 3, 3);
	cr.paint();
      }
    } catch {
    }


    cr.push_group ();

    cr.set_source_rgba (0, 0, 0, 0);
    cr.paint ();
    round_rect (cr, 0, 0, 48, 48, 5);
    cr.set_source_rgb (0.74117, 0.74117, 0.74117);
    cr.fill ();
    round_rect (cr, 1, 1, 46, 46, 5);
    cr.set_source_rgb (1, 1, 1);
    cr.fill ();
    round_rect (cr, 2, 2, 44, 44, 5);
    cr.set_source_rgb (0.341176, 0.341176, 0.341176);
    cr.fill ();
    cr.set_operator (Cairo.Operator.CLEAR);
    round_rect (cr, 3, 3, 42, 42, 5);
    cr.set_source_rgba (0, 0, 0, 0);
    cr.fill ();

    var pattern = cr.pop_group ();
    cr.set_source (pattern);
    cr.paint ();

    return Gdk.pixbuf_get_from_surface (cst, 0, 0, 48, 48);
  }
}
