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
	TelepathyGLib.IFACE_CHANNEL_TYPE_CALL);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_HANDLE_TYPE,
	(int) TelepathyGLib.HandleType.CONTACT);
    request_dict.insert (TelepathyGLib.PROP_CHANNEL_TARGET_ID, contact_id);
    request_dict.insert (
	TelepathyGLib.PROP_CHANNEL_TYPE_CALL_INITIAL_AUDIO,
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

  public static Gtk.MenuItem add_menu_item (Gtk.Menu menu, string label) {
    var mi = new Gtk.MenuItem.with_label (label);
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

  private static unichar strip_char (unichar ch) {
    switch (ch.type ()) {
    case UnicodeType.CONTROL:
    case UnicodeType.FORMAT:
    case UnicodeType.UNASSIGNED:
    case UnicodeType.NON_SPACING_MARK:
    case UnicodeType.COMBINING_MARK:
    case UnicodeType.ENCLOSING_MARK:
      /* Ignore those */
      return 0;
    default:
      return ch.tolower ();
    }
  }

  /* Returns false if the given string contains at least one non-"space"
   * character.
   */
  public static bool string_is_empty (string str) {
    unichar c;

    for (int i = 0; str.get_next_char (ref i, out c);) {
      if (!c.isspace ())
	return false;
    }

    return true;
  }

  public static string canonicalize_for_search (string str) {
    unowned string s;
    var buf = new unichar[18];
    var res = new StringBuilder ();
    for (s = str; s[0] != 0; s = s.next_char ()) {
      var c = strip_char (s.get_char ());
      if (c != 0) {
	var size = LocalGLib.fully_decompose (c, false, buf);
	if (size > 0)
	  res.append_unichar (buf[0]);
      }
    }
    return res.str;
  }

  public static void grab_widget_later (Widget widget) {
      ulong id = 0;
      id = widget.size_allocate.connect ( () => {
	  widget.grab_focus ();
	  widget.disconnect (id);
	});
  }

  public static void grab_entry_focus_no_select (Entry entry) {
    int start, end;
    if (!entry.get_selection_bounds (out start, out end)) {
      start = end = entry.get_position ();
    }
    entry.grab_focus ();
    entry.select_region (start, end);
  }

  private static void spawn_app (GLib.Settings app_settings) throws GLib.SpawnError {
    var needs_term = app_settings.get_boolean("needs-term");
    var exec = app_settings.get_string("exec");
    if (needs_term) {
      var terminal_settings = new GLib.Settings("org.gnome.desktop.default-applications.terminal");
      var term = terminal_settings.get_string("exec");
      var arg = terminal_settings.get_string("exec-arg");
      string[] args;
      if (arg != "")
	args = {term, arg, exec, null};
      else
	args = {term, exec, null};

      Process.spawn_async (null, args, null, SpawnFlags.SEARCH_PATH, null, null);
    } else {
      Process.spawn_command_line_async (exec);
    }
  }

  public static void show_calendar (DateTime? day) {
    var calendar_settings = new GLib.Settings("org.gnome.desktop.default-applications.office.calendar");
    var exec = calendar_settings.get_string("exec");
    if (exec == "" || exec == "evolution") {
      string[] args = {"evolution", "-c", "calendar", null, null};

      if (day != null) {
	var d = day.to_local ();
	var today = new DateTime.now_local ();
	args[3] = "calendar:///?startdate=%.4d%.2d%.2d".printf (today.get_year (), d.get_month (), d.get_day_of_month ());
      }

      try {
	Process.spawn_async (null, args, null, SpawnFlags.SEARCH_PATH, null, null);
      }
      catch {
      }
    } else {
      try {
	spawn_app (calendar_settings);
      }
      catch {
      }
    }
  }

  public static string[] get_stock_avatars () {
    string[] files = {};
    var system_data_dirs = Environment.get_system_data_dirs ();
    foreach (var data_dir in system_data_dirs) {
      var path = Path.build_filename (data_dir, "pixmaps", "faces");
      Dir? dir = null;
      try {
	dir = Dir.open (path);
      }	catch {
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
}
