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
public class Contacts.ListPane : Gtk.Frame {
  private Store store;

  [GtkChild]
  private Gtk.ScrolledWindow contacts_list_container;
  private ContactList contacts_list;

  [GtkChild]
  public Gtk.SearchEntry filter_entry;
  private SimpleQuery filter_query;

  [GtkChild]
  private Gtk.Button link_button;

  [GtkChild]
  private Gtk.Button delete_button;

  [GtkChild]
  private Gtk.ActionBar actions_bar;

  public UiState state { get; set; }

  public signal void selection_changed (Individual? individual);
  public signal void link_contacts (Gee.LinkedList<Individual> individual);
  public signal void delete_contacts (Gee.LinkedList<Individual> individual);
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

    this.contacts_list.selection_changed.connect( (l, individual) => {
        selection_changed (individual);
      });

    this.contacts_list.contacts_marked.connect ((nr_contacts_marked) => {
        this.delete_button.sensitive = (nr_contacts_marked > 0);
        this.link_button.sensitive = (nr_contacts_marked > 1);
        contacts_marked (nr_contacts_marked);
      });
  }

  public void undo_deletion () {
    contacts_list.show_all ();
  }

  private void on_ui_state_changed (Object obj, ParamSpec pspec) {
    // Disable when editing a contact. (Not using `this.sensitive` to allow scrolling)
    this.filter_entry.sensitive
        = this.contacts_list.sensitive
        = !this.state.editing ();

    this.actions_bar.visible = (this.state == UiState.SELECTING);
  }

  [GtkCallback]
  private void filter_entry_changed (Gtk.Editable editable) {
    this.filter_query.query_string = this.filter_entry.text;
  }

  public void select_contact (Individual? individual) {
    this.contacts_list.select_contact (individual);
  }
  
  public void hide_contact (Individual? individual) {
    this.contacts_list.hide_contact (individual);
  }

  [GtkCallback]
  private void on_link_button_clicked (Gtk.Button link_button) {
    link_contacts (this.contacts_list.get_marked_contacts ());
  }

  [GtkCallback]
  private void on_delete_button_clicked (Gtk.Button delete_button) {
    delete_contacts (this.contacts_list.get_marked_contacts_and_hide ());
  }

  /* Limiting width hack */
  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    minimum_width = natural_width = 300;
  }
}
