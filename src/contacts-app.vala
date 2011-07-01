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

public class Contacts.App : Window {
  public static App app;
  private Store contacts_store;
  private ListPane list_pane;
  private ContactPane contacts_pane;

  public override bool delete_event (Gdk.EventAny event) {
    // Clear the contacts so any changed information is stored
    contacts_pane.show_contact (null);
    return false;
  }

  public override bool map_event (Gdk.EventAny event) {
    list_pane.filter_entry.grab_focus ();
    return true;
  }

  private void selection_changed (Contact? new_selection) {
    contacts_pane.show_contact (new_selection);
  }

  public App () {
    this.app = this;
    set_title (_("Contacts"));
    set_size_request (700, 510);
    this.destroy.connect (Gtk.main_quit);

    var grid = new Grid();
    add (grid);

    contacts_store = new Store ();
    list_pane = new ListPane (contacts_store);
    list_pane.selection_changed.connect (selection_changed);
    list_pane.create_new.connect ( () => { contacts_pane.new_contact ();  });

    grid.attach (list_pane, 0, 0, 1, 2);

    contacts_pane = new ContactPane (contacts_store);
    contacts_pane.set_hexpand (true);
    grid.attach (contacts_pane, 1, 0, 1, 2);

    grid.show_all ();
  }
}
