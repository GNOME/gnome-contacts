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
  public bool is_set (string? str) {
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
                                         HashTable<string, Variant> data) throws Error;
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
    } catch (Error e) {
      debug ("Failed to activate action" + action);
    }
  }
}

namespace Contacts.Utils {
#if HAVE_TELEPATHY
  public void start_chat (Contact contact, string protocol, string id) {
    var im_persona = contact.find_im_persona (protocol, id);
    var account = (im_persona.store as Tpf.PersonaStore).account;
    var request_dict = new HashTable<string, Value?>(str_hash, str_equal);
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
    var request_dict = new HashTable<string,GLib.Value?>(str_hash, str_equal);

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

  public void grab_entry_focus_no_select (Entry entry) {
    int start, end;
    if (!entry.get_selection_bounds (out start, out end)) {
      start = end = entry.get_position ();
    }
    entry.grab_focus ();
    entry.select_region (start, end);
  }

  public string[] get_stock_avatars () {
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

  public void show_error_dialog (string error, Gtk.Window toplevel) {
    var dialog = new Gtk.MessageDialog (toplevel,
                                        Gtk.DialogFlags.MODAL,
                                        Gtk.MessageType.ERROR,
                                        Gtk.ButtonsType.OK,
                                        error);
    dialog.run();
    dialog.destroy();
  }

  public static int compare_personas_on_store (Persona? a, Persona? b) {
    if (a == null || b == null)
      return (a == null)? -1 : 1;

    var store_a = a.store;
    var store_b = b.store;

    // In the same store, sort Google 'other' contacts last
    if (store_a == store_b) {
      if (!Utils.persona_is_google (a))
        return 0;

      var a_is_other = Utils.persona_is_google_other (a);
      if (a_is_other != Utils.persona_is_google_other (b))
        return a_is_other? 1 : -1;
    }

    // Sort primary stores before others
    if (store_a.is_primary_store != store_b.is_primary_store)
      return (store_a.is_primary_store)? -1 : 1;

    // E-D-S stores get prioritized
    if ((store_a.type_id == "eds") != (store_b.type_id == "eds"))
      return (store_a.type_id == "eds")? -1 : 1;

    // Normal case: use alphabetical sorting
    return strcmp (store_a.id, store_b.id);
  }

  public bool persona_is_google (Persona persona) {
    return persona.store.type_id == "eds" && esource_uid_is_google (persona.store.id);
  }

  /**
   * Return true only for personas which are in a Google address book, but which
   * are not in the user's "My Contacts" group in the address book.
   */
  public bool persona_is_google_other (Persona persona) {
    if (!persona_is_google (persona))
      return false;

    var p = persona as Edsf.Persona;
    return p != null && !p.in_google_personal_group;
  }

  public bool persona_is_google_profile (Persona persona) {
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
}
