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
  private static bool is_set (string? str) {
    return str != null && str != "";
  }

  public Gtk.Builder load_ui (string ui) {
    var builder = new Gtk.Builder ();
    try {
        builder.add_from_resource ("/org/gnome/contacts/ui/".concat (ui, null));
    } catch (GLib.Error e) {
        error ("loading ui file: %s", e.message);
    }
    return builder;
  }

  public Gtk.CssProvider load_css (string css) {
    var provider = new Gtk.CssProvider ();
    try {
      var file = File.new_for_uri("resource:///org/gnome/contacts/ui/" + css);
      provider.load_from_file (file);
    } catch (GLib.Error e) {
      warning ("loading css: %s", e.message);
    }
    return provider;
  }

  public void add_separator (ListBoxRow row, ListBoxRow? before_row) {
    row.set_header (new Separator (Orientation.HORIZONTAL));
  }

  [DBus (name = "org.freedesktop.Application")]
  interface FreedesktopApplication : Object {
    [DBus (name = "ActivateAction")]
    public abstract void ActivateAction (string action,
                                         Variant[] parameter,
                                         HashTable<string, Variant> data) throws IOError;
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
    } catch (IOError e) {
      debug ("Failed to activate action" + action);
    }
  }
}

public class Center : Bin {
  public int max_width { get; set; }
  public double xalign { get; set; }

  public Center () {
    this.xalign = 0.5;
  }

  public override void get_preferred_height (out int minimum_height, out int natural_height) {
    var child = get_child ();
    if (child != null) {
      int min;
      int nat;
      child.get_preferred_height (out min, out nat);
      minimum_height = min;
      natural_height = nat;
    } else {
      minimum_height = -1;
      natural_height = -1;
    }
  }

  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    var child = get_child ();
    if (child != null) {
      int min;
      int nat;
      child.get_preferred_width (out min, out nat);
      minimum_width = min;
      natural_width = nat;
    } else {
      minimum_width = -1;
      natural_width = -1;
    }
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    Gtk.Allocation new_alloc;

    set_allocation (allocation);
    new_alloc = allocation;
    if (allocation.width > this.max_width) {
      new_alloc.width = this.max_width;
      new_alloc.x = (int) ((allocation.width - this.max_width) * this.xalign) + allocation.x;
    }

    var child = get_child ();
    child.size_allocate (new_alloc);
  }
}

public class Contacts.Utils : Object {
  public static void compose_mail (string email) {
    var mailto_uri = "mailto:" + Uri.escape_string (email, "@" , false);
    try {
      Gtk.show_uri_on_window (null, mailto_uri, 0);
    } catch (Error e) {
      debug ("Couldn't launch URI \"%s\": %s", mailto_uri, e.message);
    }
  }

  public static void start_chat (Contact contact, string protocol, string id) {
    var im_persona = contact.find_im_persona (protocol, id);
    var account = (im_persona.store as Tpf.PersonaStore).account;
    var request_dict = new HashTable<weak string, Value?>(str_hash, str_equal);
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

  public static void start_call (string contact_id,
                                 Gee.HashMap<string, TelepathyGLib.Account> accounts) {
    // TODO: prompt for which account to use
    var account = accounts.values.to_array ()[0];
    Utils.start_call_with_account (contact_id, account);
  }

  public static void start_call_with_account (string contact_id, TelepathyGLib.Account account) {
    var request_dict = new HashTable<weak string,GLib.Value?>(str_hash, str_equal);

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

  public static T? get_first<T> (Collection<T> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
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
        var size = c.fully_decompose (false, buf);
        if (size > 0)
          res.append_unichar (buf[0]);
      }
    }
    return res.str;
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
      } catch (Error e) {
        debug ("Couldn't spawn process \"%s\": %s", string.joinv(" ", args), e.message);
      }
    } else {
      try {
        spawn_app (calendar_settings);
      } catch (Error e) {
        debug ("Couldn't spawn calendar app: %s", e.message);
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
}
