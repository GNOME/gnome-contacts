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

using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-list-pane.ui")]
public class Contacts.ListPane : Adw.Bin {
  private Store store;

  [GtkChild]
  private unowned Adw.Bin contacts_list_container;
  private unowned ContactList contacts_list;

  [GtkChild]
  public unowned Gtk.SearchEntry filter_entry;
  private SimpleQuery filter_query;

  [GtkChild]
  private unowned Gtk.Button link_button;

  [GtkChild]
  private unowned Gtk.Button delete_button;

  [GtkChild]
  private unowned Gtk.ActionBar actions_bar;

  public UiState state { get; set; }

  public signal void selection_changed (Individual? individual);
  public signal void link_contacts (Gee.LinkedList<Individual> individual);
  public signal void delete_contacts (Gee.LinkedList<Individual> individual);
  public signal void contacts_marked (int contacts_marked);

  public ListPane (Gtk.Window window, Settings settings, Store contacts_store) {
    this.store = contacts_store;
    this.notify["state"].connect (on_ui_state_changed);

    this.filter_entry.set_key_capture_widget (window);

    // Build the filter query
    string[] filtered_fields = Query.MATCH_FIELDS_NAMES;
    foreach (var field in Query.MATCH_FIELDS_ADDRESSES)
      filtered_fields += field;
    this.filter_query = new SimpleQuery ("", filtered_fields);

    // Load the ContactsView and connect the necessary signals
    var contactslist = new ContactList (settings, contacts_store, this.filter_query);
    this.contacts_list = contactslist;
    this.contacts_list_container.set_child (contactslist);
    bind_property ("state", this.contacts_list, "state", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

    this.contacts_list.selection_changed.connect ((l, individual) => {
        selection_changed (individual);
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

    this.actions_bar.revealed = (this.state == UiState.SELECTING);
  }

  [GtkCallback]
  private void filter_entry_changed (Gtk.Editable editable) {
    this.filter_query.query_string = this.filter_entry.text;
  }

  public void select_contact (Individual? individual) {
    this.contacts_list.select_contact (individual);
  }

  public void scroll_to_contact () {
    this.contacts_list.scroll_to_contact ();
  }

  public void set_contact_visible (Individual? individual, bool visible) {
    this.contacts_list.set_contact_visible (individual, visible);
  }

  [GtkCallback]
  private void on_link_button_clicked (Gtk.Button link_button) {
    link_contacts (this.contacts_list.get_marked_contacts ());
  }

  [GtkCallback]
  private void on_delete_button_clicked (Gtk.Button delete_button) {
    delete_contacts (this.contacts_list.get_marked_contacts_and_hide ());
  }
}
