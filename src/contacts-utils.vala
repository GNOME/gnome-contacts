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
  private bool is_set (string? str) {
    return str != null && str != "";
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

namespace Contacts.Utils {
  public void compose_mail (string email) {
    var mailto_uri = "mailto:" + Uri.escape_string (email, "@" , false);
    try {
      Gtk.show_uri_on_window (null, mailto_uri, 0);
    } catch (Error e) {
      debug ("Couldn't launch URI \"%s\": %s", mailto_uri, e.message);
    }
  }

#if HAVE_TELEPATHY
  public void start_chat (Contact contact, string protocol, string id) {
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

  public void start_call (string contact_id, TelepathyGLib.Account account) {
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
#endif

  public T? get_first<T> (Collection<T> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
  }

  public void cairo_ellipsis (Cairo.Context cr,
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

  public void cairo_rounded_box (Cairo.Context cr,
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

  private unichar strip_char (unichar ch) {
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
  public bool string_is_empty (string str) {
    unichar c;

    for (int i = 0; str.get_next_char (ref i, out c);) {
      if (!c.isspace ())
        return false;
    }

    return true;
  }

  public string canonicalize_for_search (string str) {
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

  public void grab_entry_focus_no_select (Entry entry) {
    int start, end;
    if (!entry.get_selection_bounds (out start, out end)) {
      start = end = entry.get_position ();
    }
    entry.grab_focus ();
    entry.select_region (start, end);
  }

  public PersonaStore[] get_eds_address_books (Store contacts_store) {
    PersonaStore[] stores = {};
    foreach (var backend in contacts_store.backend_store.enabled_backends.values) {
      foreach (var persona_store in backend.persona_stores.values) {
        if (persona_store.type_id == "eds") {
          stores += persona_store;
        }
      }
    }
    return stores;
  }
}
