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

/**
 * The ContactList is the actual list of {@link Contact}s that the user sees on
 * the left. It is contained by the {@link ListPane}, which also provides other
 * functionality, such as an action bar.
 */
public class Contacts.ContactList : ListBox {
  private class ContactDataRow : ListBoxRow {
    private const int LIST_AVATAR_SIZE = 48;

    public Contact contact;
    public Label label;
    private Avatar avatar;
    public CheckButton selector_button;
    public bool filtered;

    public ContactDataRow(Contact c) {
      this.contact = c;

      get_style_context (). add_class ("contact-data-row");

      Grid grid = new Grid ();
      grid.margin = 3;
      grid.margin_start = 9;
      grid.set_column_spacing (10);
      this.avatar = new Avatar (LIST_AVATAR_SIZE);

      label = new Label ("");
      label.set_ellipsize (Pango.EllipsizeMode.END);
      label.set_valign (Align.CENTER);
      label.set_halign (Align.START);
      selector_button = new CheckButton ();
      selector_button.no_show_all = true;
      selector_button.set_valign (Align.CENTER);
      selector_button.set_halign (Align.END);
      selector_button.set_hexpand (true);

      grid.attach (this.avatar, 0, 0, 1, 1);
      grid.attach (label, 1, 0, 1, 1);
      grid.attach (selector_button, 2, 0, 1, 1);
      this.add (grid);
      this.show_all ();
    }

    public void update_data (bool filtered) {
      this.filtered = filtered;

      // Update widgets
      this.label.set_text (this.contact.display_name);
      this.avatar.set_image.begin (this.contact.individual, this.contact);
    }
  }

  public signal void selection_changed (Contact? contact);
  public signal void contacts_marked (int contacts_marked);

  private Map<Contact, ContactDataRow> contacts = new HashMap<Contact, ContactDataRow> ();
  int nr_contacts_marked = 0;

  string []? filter_values;
  bool selectors_visible = false;

  private Store store;

  public ContactList (Store store) {
    this.selection_mode = Gtk.SelectionMode.BROWSE;
    this.store = store;

    this.store.added.connect (contact_added_cb);
    this.store.removed.connect (contact_removed_cb);
    this.store.changed.connect (contact_changed_cb);
    foreach (var c in this.store.get_contacts ())
      contact_added_cb (this.store, c);

    get_style_context ().add_class ("contacts-contact-list");

    set_sort_func ((a, b) => compare_data (a as ContactDataRow, b as ContactDataRow));
    set_filter_func (filter);
    set_header_func (update_header);

    show ();
  }

  private int compare_data (ContactDataRow a_data, ContactDataRow b_data) {
    var a = a_data.contact.individual;
    var b = b_data.contact.individual;

    // Always prefer favourites over non-favourites.
    if (a.is_favourite != b.is_favourite)
      return a.is_favourite? -1 : 1;

    // Both are (non-)favourites: sort by name
    if (is_set (a.display_name) && is_set (b.display_name))
      return a.display_name.collate (b.display_name);

    // Sort empty names last
    if (is_set (a.display_name))
      return -1;
    if (is_set (b.display_name))
      return 1;

    return 0;
  }

  private void update_header (ListBoxRow row, ListBoxRow? before) {
    var current = ((ContactDataRow) row).contact.individual;

    if (before == null) {
      if (current.is_favourite)
        row.set_header (create_header_label (_("Favorites")));
      else
        row.set_header (create_header_label (_("All Contacts")));
      return;
    }

    var previous = ((ContactDataRow) before).contact.individual;
    if (!current.is_favourite && previous.is_favourite) {
      row.set_header (create_header_label (_("All Contacts")));
    } else {
      row.set_header (null);
    }
  }

  private Label create_header_label (string text) {
    var label = new Label (text);
    label.halign = Align.START;
    label.margin = 3;
    label.margin_start = 6;
    label.margin_top = 6;
    var attrs = new Pango.AttrList ();
    attrs.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
    attrs.insert (Pango.attr_scale_new ((Pango.Scale.SMALL + Pango.Scale.MEDIUM) / 2.0));
    attrs.insert (Pango.attr_foreground_alpha_new (30000));
    label.attributes = attrs;
    return label;
  }

  public void set_filter_values (string []? values) {
    if (filter_values == values)
      return;

    if (filter_values == null)
      set_placeholder (null);
    else {
      var l = new Label (_("No results matched search"));
      l.show ();
      set_placeholder (l);
    }
    filter_values = values;
    update_all_filtered ();
    invalidate_filter ();
  }

  private bool calculate_filtered (Contact c) {
    if (c.is_hidden)
      return false;

    if (filter_values == null || filter_values.length == 0)
      return true;

    return c.contains_strings (filter_values);
  }

  private void update_all_filtered () {
    foreach (var widget in get_children ()) {
      var row = widget as ContactDataRow;
      row.filtered = calculate_filtered (row.contact);
    }
  }

  private void contact_changed_cb (Store store, Contact c) {
    var data = contacts.get (c);
    data.update_data (calculate_filtered (c));
    data.changed();
  }

  private void contact_added_cb (Store store, Contact c) {
    var data =  new ContactDataRow(c);

    data.update_data (calculate_filtered (c));

    data.selector_button.toggled.connect (() => {
	if (data.selector_button.active)
	  this.nr_contacts_marked++;
	else
	  this.nr_contacts_marked--;

	contacts_marked (this.nr_contacts_marked);
      });

    if (! selectors_visible)
      data.selector_button.hide ();
    contacts.set (c, data);
    this.add (data);
  }

  private void contact_removed_cb (Store store, Contact c) {
    var data = contacts.get (c);
    contacts.unset (c);
    data.destroy ();
  }

  public override void row_selected (ListBoxRow? row) {
    var data = row as ContactDataRow;
    var contact = data != null ? data.contact : null;
    selection_changed (contact);
#if HAVE_TELEPATHY
    if (contact != null)
      contact.fetch_contact_info ();
#endif
  }

  private bool filter (ListBoxRow row) {
    var data = row as ContactDataRow;
    return data.filtered;
  }

  public void select_contact (Contact? contact) {
    if (contact == null) {
      /* deselect */
      select_row (null);
      return;
    }

    var data = contacts.get (contact);
    select_row (data);
  }

  public void show_selectors () {
    foreach (var widget in get_children ()) {
      var row = widget as ContactDataRow;
      row.selector_button.show ();
    }
    selectors_visible = true;
  }

  public void hide_selectors () {
    foreach (var widget in get_children ()) {
      var row = widget as ContactDataRow;
      row.selector_button.hide ();
      row.selector_button.set_active (false);
    }
    selectors_visible = false;
    nr_contacts_marked = 0;
  }

  public LinkedList<Contact> get_marked_contacts () {
    var cs = new LinkedList<Contact> ();
    foreach (var widget in get_children ()) {
      var row = widget as ContactDataRow;
      if (row.selector_button.active)
        cs.add (row.contact);
    }
    return cs;
  }
}
