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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-list-pane.ui")]
public class Contacts.ListPane : Frame {
  private Store store;

  [GtkChild]
  private Gtk.ScrolledWindow contacts_view_container;
  private View contacts_view;

  [GtkChild]
  public ToolItem search_tool_item;

  [GtkChild]
  public SearchEntry filter_entry;

  [GtkChild]
  public Button link_button;

  [GtkChild]
  public Button delete_button;

  [GtkChild]
  public ActionBar actions_bar;

  private uint filter_entry_changed_id;
  private bool ignore_selection_change;

  public signal void selection_changed (Contact? contact);

  public signal void link_contacts (LinkedList<Contact> contacts_list);
  public signal void delete_contacts (LinkedList<Contact> contacts_list);

  public signal void contacts_marked (int contacts_marked);

  public void refilter () {
    string []? values;
    string str = filter_entry.get_text ();

    if (Utils.string_is_empty (str))
      values = null;
    else {
      str = Utils.canonicalize_for_search (str);
      values = str.split(" ");
    }

    this.contacts_view.set_filter_values (values);
  }

  private bool filter_entry_changed_timeout () {
    filter_entry_changed_id = 0;
    refilter ();
    return false;
  }

  [GtkCallback]
  private void filter_entry_changed (Editable editable) {
    if (filter_entry_changed_id != 0)
      Source.remove (filter_entry_changed_id);

    filter_entry_changed_id = Timeout.add (300, filter_entry_changed_timeout);
  }

  public ListPane (Store contacts_store) {
    this.store = contacts_store;

    // Load the ContactsView and connect the necessary signals
    this.contacts_view = new View (contacts_store);
    this.contacts_view_container.add (this.contacts_view);

    this.contacts_view.selection_changed.connect( (l, contact) => {
        if (!this.ignore_selection_change)
          selection_changed (contact);
      });

    this.contacts_view.contacts_marked.connect ((nr_contacts_marked) => {
        this.delete_button.sensitive = (nr_contacts_marked > 0);
        this.link_button.sensitive = (nr_contacts_marked > 1);
        contacts_marked (nr_contacts_marked);
      });
  }

  public void select_contact (Contact? contact, bool ignore_change = false) {
    if (ignore_change)
      ignore_selection_change = true;
    this.contacts_view.select_contact (contact);
    ignore_selection_change = false;
  }

  public void show_selection () {
    this.contacts_view.show_selectors ();
    actions_bar.show ();
  }

  public void hide_selection () {
    this.contacts_view.hide_selectors ();
    actions_bar.hide ();
  }

  [GtkCallback]
  private void on_link_button_clicked (Gtk.Button link_button) {
    link_contacts (this.contacts_view.get_marked_contacts ());
  }

  [GtkCallback]
  private void on_delete_button_clicked (Gtk.Button delete_button) {
    var marked_contacts = contacts_view.get_marked_contacts ();
    foreach (var c in marked_contacts)
      c.hide ();
    delete_contacts (marked_contacts);
  }

  /* Limiting width hack */
  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    minimum_width = natural_width = 300;
  }
}
