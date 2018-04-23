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
  private Gtk.ScrolledWindow contacts_list_container;
  private ContactList contacts_list;

  [GtkChild]
  public SearchEntry filter_entry;
  private SimpleQuery filter_query;

  [GtkChild]
  private Button link_button;

  [GtkChild]
  private Button delete_button;

  [GtkChild]
  private ActionBar actions_bar;

  public UiState state { get; set; }

  public signal void selection_changed (Contact? contact);
  public signal void link_contacts (LinkedList<Contact> contacts);
  public signal void delete_contacts (LinkedList<Contact> contacts);
  public signal void contacts_marked (int contacts_marked);

  public ListPane (Settings settings, Store contacts_store) {
    this.store = contacts_store;
    this.notify["state"].connect (on_ui_state_changed);

    // Build the filter query
    string[] filtered_fields = Query.MATCH_FIELDS_NAMES;
    foreach (var field in Query.MATCH_FIELDS_ADDRESSES)
      filtered_fields += field;
    this.filter_query = new SimpleQuery ("", filtered_fields);


    // Load the ContactsView and connect the necessary signals
    this.contacts_list = new ContactList (settings, contacts_store, this.filter_query);
    bind_property ("state", this.contacts_list, "state", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
    this.contacts_list_container.add (this.contacts_list);

    this.contacts_list.selection_changed.connect( (l, contact) => {
        selection_changed (contact);
      });

    this.contacts_list.contacts_marked.connect ((nr_contacts_marked) => {
        this.delete_button.sensitive = (nr_contacts_marked > 0);
        this.link_button.sensitive = (nr_contacts_marked > 1);
        contacts_marked (nr_contacts_marked);
      });
  }

  private void on_ui_state_changed (Object obj, ParamSpec pspec) {
    // Disable when editing a contact. (Not using `this.sensitive` to allow scrolling)
    this.filter_entry.sensitive
        = this.contacts_list.sensitive
        = !this.state.editing ();

    this.actions_bar.visible = (this.state == UiState.SELECTING);
  }

  [GtkCallback]
  private void filter_entry_changed (Editable editable) {
    this.filter_query.query_string = this.filter_entry.text;
  }

  public void select_contact (Contact? contact) {
    this.contacts_list.select_contact (contact);
  }

  [GtkCallback]
  private void on_link_button_clicked (Gtk.Button link_button) {
    link_contacts (this.contacts_list.get_marked_contacts ());
  }

  [GtkCallback]
  private void on_delete_button_clicked (Gtk.Button delete_button) {
    delete_selection ();
  }

  public void delete_selection () {
    if (this.state != UiState.SELECTING)
      return;

    var marked_contacts = this.contacts_list.get_marked_contacts ();
    foreach (var c in marked_contacts)
      c.hidden = true;
    delete_contacts (marked_contacts);
  }

  /* Limiting width hack */
  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    minimum_width = natural_width = 300;
  }
}
