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

public class Contacts.View : ListBox {
  private class ContactDataRow : ListBoxRow {
    public Contact contact;
    public Label label;
    public ContactFrame image_frame;
    public CheckButton selector_button;
    public bool filtered;

    public ContactDataRow(Contact c) {
      this.contact = c;

      get_style_context (). add_class ("contact-data-row");

      Grid grid = new Grid ();
      grid.margin = 6;
      grid.set_column_spacing (10);
      image_frame = new ContactFrame (Contact.LIST_AVATAR_SIZE);
      image_frame.set_shadow_type (ShadowType.IN);
      image_frame.get_style_context ().add_class ("main-avatar-frame");

      label = new Label ("");
      label.set_ellipsize (Pango.EllipsizeMode.END);
      label.set_valign (Align.CENTER);
      label.set_halign (Align.START);
      selector_button = new CheckButton ();
      selector_button.no_show_all = true;
      selector_button.set_valign (Align.CENTER);
      selector_button.set_halign (Align.END);
      selector_button.set_hexpand (true);

      grid.attach (image_frame, 0, 0, 1, 1);
      grid.attach (label, 1, 0, 1, 1);
      grid.attach (selector_button, 2, 0, 1, 1);
      this.add (grid);
      this.show_all ();
    }

    public void update_data (bool filtered) {
      this.filtered = filtered;

      // Update widgets
      this.label.set_text (this.contact.display_name);
      this.image_frame.set_image (this.contact.individual, this.contact);
    }
  }

  public enum Subset {
    MAIN,
    OTHER,
    ALL_SEPARATED,
    ALL
  }

  public enum TextDisplay {
    NONE,
    PRESENCE,
    STORES
  }

  public signal void selection_changed (Contact? contact);
  public signal void contacts_marked (int contacts_marked);

  Subset show_subset = Subset.ALL;
  HashMap<Contact,ContactDataRow> contacts;
  HashSet<Contact> hidden_contacts;
  int nr_contacts_marked = 0;

  string []? filter_values;
  bool selectors_visible = false;

  private Store _store;

  public Store store {
    get {
      return _store;
    }
    set {
      _store = value;

      _store.added.connect (contact_added_cb);
      _store.removed.connect (contact_removed_cb);
      _store.changed.connect (contact_changed_cb);
      foreach (var c in _store.get_contacts ())
        contact_added_cb (_store, c);
    }
  }

  construct {
    hidden_contacts = new HashSet<Contact>();

    contacts = new HashMap<Contact,ContactDataRow> ();

    this.set_sort_func ((row_a, row_b) => {
	var a = row_a as ContactDataRow;
	var b = row_b as ContactDataRow;
	return compare_data (a, b);
      });
    this.set_filter_func (filter);
  }

  private int compare_data (ContactDataRow a_data, ContactDataRow b_data) {
    if (is_set (a_data.contact.display_name) && is_set (b_data.contact.display_name))
      return a_data.contact.display_name.collate (b_data.contact.display_name);

    // Sort empty names last
    if (is_set (a_data.contact.display_name))
      return -1;
    if (is_set (b_data.contact.display_name))
      return 1;

    return 0;
  }

  private bool is_other (ContactDataRow data) {
    if (show_subset == Subset.ALL_SEPARATED &&
	data.contact != null &&
	!data.contact.is_main)
      return true;
    return false;
  }

  public void set_show_subset (Subset subset) {
    show_subset = subset;
    update_all_filtered ();
    invalidate_filter ();
    invalidate_sort ();
  }

  public void hide_contact (Contact contact) {
    hidden_contacts.add (contact);
    update_all_filtered ();
    invalidate_filter ();
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

    if (c in hidden_contacts)
      return false;

    if ((show_subset == Subset.MAIN &&
	 !c.is_main) ||
	(show_subset == Subset.OTHER &&
	 c.is_main))
      return false;

    if (filter_values == null || filter_values.length == 0)
      return true;

    return c.contains_strings (filter_values);
  }

  private void update_all_filtered () {
    foreach (var data in contacts.values) {
      data.filtered = calculate_filtered (data.contact);
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
    if (contact != null)
      contact.fetch_contact_info ();
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
    foreach (var data in contacts.values) {
      data.selector_button.show ();
    }
    selectors_visible = true;
  }

  public void hide_selectors () {
    foreach (var data in contacts.values) {
      data.selector_button.hide ();
      data.selector_button.set_active (false);
    }
    selectors_visible = false;
    nr_contacts_marked = 0;
  }

  public LinkedList<Contact> get_marked_contacts () {
    var cs = new LinkedList<Contact> ();
    foreach (var data in contacts.values) {
      if (data.selector_button.active)
	cs.add (data.contact);
    }
    return cs;
  }
}
