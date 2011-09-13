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

namespace Contacts {
  private static bool is_set (string? str) {
    return str != null && str != "";
  }
}


public class Contacts.Utils : Object {
  public static void compose_mail (string email) {
    try {
      Gtk.show_uri (null, "mailto:" + Uri.escape_string (email, "@" , false), 0);
    } catch {
    }
  }

  public static void start_chat (Contact contact, string protocol, string id) {
    var im_persona = contact.find_im_persona (protocol, id);
    var account = (im_persona.store as Tpf.PersonaStore).account;
    var request_dict = new HashTable<weak string,GLib.Value?>(str_hash, str_equal);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_CHANNEL_TYPE, TelepathyGLib.IFACE_CHANNEL_TYPE_TEXT);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_HANDLE_TYPE, (int) TelepathyGLib.HandleType.CONTACT);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_ID, id);

    // TODO: Should really use the event time like:
    // tp_user_action_time_from_x11(gtk_get_current_event_time())
    var request = new TelepathyGLib.AccountChannelRequest(account, request_dict, int64.MAX);
    request.ensure_channel_async.begin ("org.freedesktop.Telepathy.Client.Empathy.Chat", null);
  }

  public static void start_call (string contact_id,
      Gee.HashMap<string, Account> accounts) {
    // TODO: prompt for which account to use
    var account = accounts.values.to_array ()[0];
    Utils.start_call_with_account (contact_id, account);
  }

  public static void start_call_with_account (string contact_id,
      Account account) {
    var request_dict = new HashTable<weak string,GLib.Value?>(str_hash,
	str_equal);

    request_dict.insert (TelepathyGLib.PROP_CHANNEL_CHANNEL_TYPE,
	TelepathyGLib.IFACE_CHANNEL_TYPE_STREAMED_MEDIA);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_HANDLE_TYPE,
	(int) TelepathyGLib.HandleType.CONTACT);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_ID, contact_id);
    request_dict.insert (
	TelepathyGLib.PROP_CHANNEL_TYPE_STREAMED_MEDIA_INITIAL_AUDIO,
	true);

    var request = new TelepathyGLib.AccountChannelRequest(account,
	request_dict, int64.MAX);
    request.ensure_channel_async.begin (
	"org.freedesktop.Telepathy.Client.Empathy.Call", null);
  }

  public static T? get_first<T> (Collection<T> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
  }

  public static MenuItem add_menu_item (Menu menu, string label) {
    var mi = new MenuItem.with_label (label);
    menu.append (mi);
    mi.show ();
    return mi;
  }

  public static void grid_insert_row_after (Grid grid, Widget widget, bool expand_intersecting) {
    int y, h;
    grid.child_get (widget,
		    "top-attach", out y,
		    "height", out h);
    int start = y + h;
    foreach (var child in grid.get_children ()) {
      grid.child_get (child,
		      "top-attach", out y,
		      "height", out h);
      if (y >= start) {
	grid.child_set (child,
			"top-attach", y + 1);
      } else if (y + h > start && expand_intersecting) {
	grid.child_set (child,
			"height", h + 1);
      }
    }
  }

  public static void cairo_ellipsis (Cairo.Context cr,
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

  public static void cairo_rounded_box (Cairo.Context cr,
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
}
