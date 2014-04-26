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

using Gee;
using Gtk;
using Folks;

[GtkTemplate (ui = "/org/gnome/contacts/contacts-window.ui")]
public class Contacts.Window : Gtk.ApplicationWindow {
  [GtkChild]
  private HeaderBar left_toolbar;
  [GtkChild]
  private HeaderBar right_toolbar;
  [GtkChild]
  private Overlay overlay;
  [GtkChild]
  private ListPane list_pane;
  [GtkChild]
  private Button edit_button;
  [GtkChild]
  private Button done_button;

  [GtkChild]
  public Store contacts_store;

  [GtkChild]
  public ContactPane contacts_pane;

  /* FIXME: remove from public what it is not needed */
  [GtkChild]
  public Button add_button;
  [GtkChild]
  public ToggleButton select_button;

  public string left_title {
    get {
      return left_toolbar.get_title ();
    }
    set {
      left_toolbar.set_title (value);
    }
  }

  public string right_title {
    get {
      return right_toolbar.get_title ();
    }
    set {
      right_toolbar.set_title (value);
    }
  }

  public Window (Gtk.Application app) {
    Object (application: app);

    string layout_desc;
    string[] tokens;

    layout_desc = Gtk.Settings.get_default ().gtk_decoration_layout;
    tokens = layout_desc.split (":", 2);
    if (tokens != null) {
      right_toolbar.decoration_layout = ":%s".printf (tokens[1]);
      left_toolbar.decoration_layout = tokens[0];
    }

    connect_content_widgets ();
  }

  public void activate_selection_mode (bool active) {
    if (active) {
      add_button.hide ();

      left_toolbar.get_style_context ().add_class ("selection-mode");
      right_toolbar.get_style_context ().add_class ("selection-mode");

      left_toolbar.set_title (_("Select"));
    } else {
      add_button.show ();

      left_toolbar.get_style_context ().remove_class ("selection-mode");
      right_toolbar.get_style_context ().remove_class ("selection-mode");

      left_toolbar.set_title (_("All Contacts"));
    }
  }

  public void add_notification (Widget notification) {
    overlay.add_overlay (notification);
  }

  public void set_shown_contact (Contact? c) {
    /* FIXME: ask the user to leave edit-mode and act accordingly */
    if (contacts_pane.on_edit_mode) {
      contacts_pane.set_edit_mode (false);

      right_title = "";
    }
    done_button.hide ();

    contacts_pane.show_contact (c, false);

    /* clearing right_toolbar */
    if (c != null) {
      right_title = c.display_name;
    }
    edit_button.visible = (c != null);
  }

  /* internal API */
  void connect_content_widgets () {
    list_pane.contacts_marked.connect ((nr_contacts) => {
	if (nr_contacts == 0) {
	  left_title = _("Select");
	} else {
	  left_title = ngettext ("%d Selected",
				 "%d Selected", nr_contacts).printf (nr_contacts);
	}
      });

    select_button.toggled.connect (() => {
        if (select_button.active) {
	  /* Update UI */
	  activate_selection_mode (true);

          list_pane.show_selection ();
	} else {
          list_pane.hide_selection ();

	  /* Update UI */
	  activate_selection_mode (false);
	}
      });

    edit_button.clicked.connect (() => {
	if (contacts_pane.contact == null)
	  return;

	if (select_button.active)
	  select_button.set_active (false);

	var name = contacts_pane.contact.display_name;
	right_title = _("Editing %s").printf (name);

	edit_button.hide ();
	done_button.show ();
	contacts_pane.set_edit_mode (true);
      });

    done_button.clicked.connect (() => {
	done_button.hide ();
	edit_button.show ();
	contacts_pane.set_edit_mode (false);

	if (contacts_pane.contact != null) {
	  right_title = contacts_pane.contact.display_name;
	}
      });
  }

  [GtkCallback]
  bool key_press_event_cb (Gdk.EventKey event) {
    if ((event.keyval == Gdk.keyval_from_name ("q")) &&
        ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)) {
      // Clear the contacts so any changed information is stored
      contacts_pane.show_contact (null);
      destroy ();
    } else if (((event.keyval == Gdk.Key.s) ||
                (event.keyval == Gdk.Key.f)) &&
               ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)) {
      Utils.grab_entry_focus_no_select (list_pane.filter_entry);
    } else if (event.length >= 1 &&
               Gdk.keyval_to_unicode (event.keyval) != 0 &&
               (event.state & Gdk.ModifierType.CONTROL_MASK) == 0 &&
               (event.state & Gdk.ModifierType.MOD1_MASK) == 0 &&
               (event.keyval != Gdk.Key.Escape) &&
               (event.keyval != Gdk.Key.Tab) &&
               (event.keyval != Gdk.Key.BackSpace) ) {
      Utils.grab_entry_focus_no_select (list_pane.filter_entry);
      propagate_key_event (event);
    }

    return false;
  }

  [GtkCallback]
  bool delete_event_cb (Gdk.EventAny event) {
    // Clear the contacts so any changed information is stored
    contacts_pane.show_contact (null);
    return false;
  }

  [GtkCallback]
  void list_pane_selection_changed_cb (Contact? new_selection) {
    set_shown_contact (new_selection);
  }

  [GtkCallback]
  void list_pane_link_contacts_cb (LinkedList<Contact> contact_list) {
    /* getting out of selection mode */
    set_shown_contact (null);
    select_button.set_active (false);

    LinkOperation2 operation = null;
    link_contacts_list.begin (contact_list, (obj, result) => {
        operation = link_contacts_list.end (result);
      });

    var notification = new Gd.Notification ();
    notification.timeout = 5;

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg = ngettext ("%d contacts linked",
                           "%d contacts linked",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.with_mnemonic (_("_Undo"));
    g.add (new Label (msg));
    g.add (b);

    notification.show_all ();
    add_notification (notification);

    /* signal handlers */
    b.clicked.connect ( () => {
        /* here, we will unlink the thing in question */
        operation.undo.begin ();

        notification.dismiss ();
      });
  }

  [GtkCallback]
  void list_pane_delete_contacts_cb (LinkedList<Contact> contact_list) {
    /* getting out of selection mode */
    set_shown_contact (null);
    select_button.set_active (false);

    var notification = new Gd.Notification ();
    notification.timeout = 5;

    var g = new Grid ();
    g.set_column_spacing (8);
    notification.add (g);

    string msg = ngettext ("%d contact deleted",
                           "%d contacts deleted",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.with_mnemonic (_("_Undo"));
    g.add (new Label (msg));
    g.add (b);

    notification.show_all ();
    add_notification (notification);

    /* signal handlers */
    bool really_delete = true;
    notification.dismissed.connect ( () => {
        if (really_delete) {
          foreach (var c in contact_list) {
            c.remove_personas.begin ();
          }
        }
      });
    b.clicked.connect ( () => {
        really_delete = false;
        notification.dismiss ();
	foreach (var c in contact_list) {
	  c.show ();
	}
	set_shown_contact (contact_list.last ());
      });
  }
}
