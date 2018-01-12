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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-window.ui")]
public class Contacts.Window : Gtk.ApplicationWindow {
  [GtkChild]
  private Grid content_grid;
  [GtkChild]
  private Container contact_pane_container;
  [GtkChild]
  private Grid loading_box;
  [GtkChild]
  private SizeGroup left_pane_size_group;
  [GtkChild]
  private HeaderBar left_header;
  [GtkChild]
  private HeaderBar right_header;
  [GtkChild]
  private Overlay overlay;
  [GtkChild]
  private Button add_button;
  [GtkChild]
  private Button select_button;
  [GtkChild]
  private Button select_cancel_button;
  [GtkChild]
  private Button edit_button;
  [GtkChild]
  private Button cancel_button;
  [GtkChild]
  private Button done_button;

  [GtkChild]
  private Stack view_switcher;

  // The 2 panes the window consists of
  private ListPane list_pane;
  private ContactPane contact_pane;

  public Store store {
    get; construct set;
  }

  private bool selection_mode = false;
  private bool editing_new_contact = false;

  public Window (App app, Store contacts_store, Settings settings) {
    Object (
      application: app,
      show_menubar: false,
      store: contacts_store
    );
    debug ("everyone creation: finalized already!!!");

    create_contact_pane ();

    view_switcher.visible_child_name = "content-view";

    set_headerbar_layout ();
    connect_button_signals ();
  }

  private void create_contact_pane () {
    this.contact_pane = new ContactPane (this, this.store);
    this.contact_pane.visible = true;
    this.contact_pane.hexpand = true;
    this.contact_pane.will_delete.connect (contact_pane_delete_contact_cb);
    this.contact_pane.contacts_linked.connect (contact_pane_contacts_linked_cb);
    this.contact_pane_container.add (this.contact_pane);
  }

  public void set_list_pane () {
    /* FIXME: if no contact is loaded per backend, I must place a sign
     * saying "import your contacts/add online account" */
    if (list_pane != null)
      return;

    list_pane = new ListPane (store);
    list_pane.selection_changed.connect (list_pane_selection_changed_cb);
    list_pane.link_contacts.connect (list_pane_link_contacts_cb);
    list_pane.delete_contacts.connect (list_pane_delete_contacts_cb);

    list_pane.contacts_marked.connect ((nr_contacts) => {
        if (nr_contacts == 0)
          this.left_header.title = _("Select");
        else
          this.left_header.title = ngettext ("%d Selected", "%d Selected", nr_contacts)
                                       .printf (nr_contacts);
      });

    left_pane_size_group.add_widget (list_pane);
    left_pane_size_group.remove_widget (loading_box);
    loading_box.destroy ();

    content_grid.attach (list_pane, 0, 0, 1, 1);

    if (this.contact_pane.contact != null)
      list_pane.select_contact (this.contact_pane.contact);

    list_pane.show ();
  }

  public void activate_selection_mode (bool active) {
    this.selection_mode = active;

    // Show some buttons when selecting (and vice versa)
    this.select_cancel_button.visible = active;
    // and hide some
    this.select_button.visible = !active;
    this.add_button.visible = !active;
    this.edit_button.visible = !active;
    this.right_header.show_close_button = !active;

    this.list_pane.activate_selection_mode (active);

    if (active) {
      left_header.get_style_context ().add_class ("selection-mode");
      right_header.get_style_context ().add_class ("selection-mode");

      left_header.set_title (_("Select"));

    } else {
      left_header.get_style_context ().remove_class ("selection-mode");
      right_header.get_style_context ().remove_class ("selection-mode");

      left_header.set_title (_("All Contacts"));

      /* could be no contact selected whatsoever */
      if (this.contact_pane.contact == null)
        edit_button.hide ();
    }
  }

  private void activate_edit_mode (bool active) {
    this.done_button.visible = active;
    this.cancel_button.visible = active;

    this.edit_button.visible = !active;
    this.add_button.visible = !active;
    this.select_button.visible = !active;
    this.right_header.show_close_button = !active;

    if (active) {
      left_header.get_style_context ().add_class ("selection-mode");
      right_header.get_style_context ().add_class ("selection-mode");
    } else {
      left_header.get_style_context ().remove_class ("selection-mode");
      right_header.get_style_context ().remove_class ("selection-mode");
    }
  }

  private void edit_contact () {
    if (this.contact_pane.contact == null)
      return;

    activate_edit_mode (true);

    var name = this.contact_pane.contact.display_name;
    this.right_header.title = _("Editing %s").printf (name);

    this.contact_pane.set_edit_mode (true);
  }

  private void leave_edit_mode (bool drop_changes = false) {
    activate_edit_mode (false);

    if (this.editing_new_contact) {
      done_button.label = _("Done");

      if (drop_changes) {
        this.contact_pane.set_edit_mode (false, drop_changes);
      } else {
        this.contact_pane.create_contact.begin ();
      }
      this.editing_new_contact = false;
    } else {
      this.contact_pane.set_edit_mode (false, drop_changes);
    }

    if (this.contact_pane.contact != null) {
      this.right_header.title = this.contact_pane.contact.display_name;
    } else {
      this.right_header.title = "";
      edit_button.hide ();
    }
  }

  public void add_notification (InAppNotification notification) {
    this.overlay.add_overlay (notification);
    notification.show ();
  }

  public void set_shown_contact (Contact? c) {
    /* FIXME: ask the user to leave edit-mode and act accordingly */
    if (this.contact_pane.on_edit_mode)
      leave_edit_mode ();

    this.contact_pane.show_contact (c, false);
    if (list_pane != null)
      list_pane.select_contact (c);

    // clearing right_header
    this.right_header.title = (c != null)? c.display_name : "";

    edit_button.visible = (c != null) && !this.selection_mode;
  }

  [GtkCallback]
  public void new_contact () {
    /* FIXME: eventually ContactPane will become just a skeleton and
     * this call will go through to ContactEditor */
    activate_edit_mode (true);
    this.editing_new_contact = true;

    this.right_header.title = _("New Contact");
    this.done_button.label = _("Add");

    this.contact_pane.new_contact ();
  }

  public void show_search (string query) {
    list_pane.filter_entry.set_text (query);
  }

  private void set_headerbar_layout () {
    // Propagate the decoration layout to the separate headerbars, so
    // that we know, for example, on which side the close button should be.
    string layout_desc = Gtk.Settings.get_default ().gtk_decoration_layout;
    string[] tokens = layout_desc.split (":", 2);
    if (tokens != null) {
      this.right_header.decoration_layout = ":%s".printf (tokens[1]);
      this.left_header.decoration_layout = tokens[0];
    }
  }

  private void connect_button_signals () {
    this.select_button.clicked.connect (() => activate_selection_mode (true));
    this.select_cancel_button.clicked.connect (() => activate_selection_mode (false));
    this.edit_button.clicked.connect (() => edit_contact ());
    this.done_button.clicked.connect (() => leave_edit_mode ());
    this.cancel_button.clicked.connect (() => leave_edit_mode (true));
  }

  [GtkCallback]
  bool key_press_event_cb (Gdk.EventKey event) {
    if ((event.keyval == Gdk.keyval_from_name ("q")) &&
        ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)) {
      // Clear the contacts so any changed information is stored
      this.contact_pane.show_contact (null);
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
    this.contact_pane.show_contact (null);
    return false;
  }

  void list_pane_selection_changed_cb (Contact? new_selection) {
    set_shown_contact (new_selection);
  }

  void list_pane_link_contacts_cb (LinkedList<Contact> contact_list) {
    /* getting out of selection mode */
    set_shown_contact (null);
    activate_selection_mode (false);

    LinkOperation2 operation = null;
    link_contacts_list.begin (contact_list, this.store, (obj, result) => {
        operation = link_contacts_list.end (result);
      });

    string msg = ngettext ("%d contacts linked",
                           "%d contacts linked",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.with_mnemonic (_("_Undo"));

    var notification = new InAppNotification (msg);
    /* signal handlers */
    b.clicked.connect ( () => {
        /* here, we will unlink the thing in question */
        operation.undo.begin ();
        notification.dismiss ();
      });

    add_notification (notification);
  }

  void list_pane_delete_contacts_cb (LinkedList<Contact> contact_list) {
    /* getting out of selection mode */
    set_shown_contact (null);
    activate_selection_mode (false);

    string msg = ngettext ("%d contact deleted",
                           "%d contacts deleted",
                           contact_list.size).printf (contact_list.size);

    var b = new Button.with_mnemonic (_("_Undo"));

    var notification = new InAppNotification (msg, b);

    /* signal handlers */
    bool really_delete = true;
    b.clicked.connect ( () => {
        really_delete = false;
        notification.dismiss ();
      });
    notification.dismissed.connect ( () => {
        if (really_delete)
          foreach (var c in contact_list)
            c.remove_personas.begin ();
      });

    add_notification (notification);

	foreach (var c in contact_list) {
	  c.show ();
	}
	set_shown_contact (contact_list.last ());
  }

  private void contact_pane_delete_contact_cb (Contact contact) {
    /* unsetting edit-mode */
    set_shown_contact (null);
    activate_selection_mode (false);

    var msg = _("Contact deleted: “%s”").printf (contact.display_name);
    var b = new Button.with_mnemonic (_("_Undo"));

    var notification = new InAppNotification (msg, b);
    // Don't wrap (default), but ellipsize
    notification.message_label.wrap = false;
    notification.message_label.max_width_chars = 45;
    notification.message_label.ellipsize = Pango.EllipsizeMode.END;

    bool really_delete = true;
    notification.dismissed.connect ( () => {
        if (really_delete)
          contact.remove_personas.begin ( () => {
              contact.show ();
            });
      });
    add_notification (notification);
    b.clicked.connect ( () => {
        really_delete = false;
        notification.dismiss ();
        contact.show ();
        set_shown_contact (contact);
      });
  }

  void contact_pane_contacts_linked_cb (string? main_contact, string linked_contact, LinkOperation operation) {
    string msg;
    if (main_contact != null)
      msg = _("%s linked to %s").printf (main_contact, linked_contact);
    else
      msg = _("%s linked to the contact").printf (linked_contact);

    var b = new Button.with_mnemonic (_("_Undo"));
    var notification = new InAppNotification (msg, b);

    b.clicked.connect ( () => {
        notification.dismiss ();
        operation.undo.begin ();
      });

    add_notification (notification);
  }
}
