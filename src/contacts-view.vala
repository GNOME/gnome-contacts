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

using Gtk;
using Folks;
using Gee;

public class Contacts.View : ListBox {
  private class ContactDataRow : ListBoxRow {
    public Contact contact;
    public Grid grid;
    public Label label;
    public ContactFrame image_frame;
    public CheckButton selector_button;
    public int sort_prio;
    public string display_name;
    public unichar initial_letter;
    public bool filtered;

    public ContactDataRow(Contact c) {
      this.contact = c;
      grid = new Grid ();
      grid.margin = 6;
      grid.set_column_spacing (10);
      image_frame = new ContactFrame (Contact.LIST_AVATAR_SIZE);
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

    public void update_widgets () {
      label.set_text (display_name);
      image_frame.set_image (contact.individual, contact);
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

  Store contacts_store;
  Subset show_subset;
  HashMap<Contact,ContactDataRow> contacts;
  HashSet<Contact> hidden_contacts;
  int nr_contacts_marked;

  string []? filter_values;
  TextDisplay text_display;
  bool selectors_visible;
  Widget last_selected;

  public View (Store store, TextDisplay text_display = TextDisplay.PRESENCE) {
    set_selection_mode (SelectionMode.BROWSE);
    contacts_store = store;
    hidden_contacts = new HashSet<Contact>();
    nr_contacts_marked = 0;
    show_subset = Subset.ALL;
    this.text_display = text_display;

    contacts = new HashMap<Contact,ContactDataRow> ();

    this.set_sort_func ((row_a, row_b) => {
	var a = row_a as ContactDataRow;
	var b = row_b as ContactDataRow;
	return compare_data (a, b);
      });
    this.set_filter_func (filter);
    this.set_header_func (update_header);

    selectors_visible = false;

    contacts_store.added.connect (contact_added_cb);
    contacts_store.removed.connect (contact_removed_cb);
    contacts_store.changed.connect (contact_changed_cb);
    foreach (var c in store.get_contacts ())
      contact_added_cb (store, c);
  }

  private int compare_data (ContactDataRow a_data, ContactDataRow b_data) {
    int a_prio = get_sort_prio (a_data);
    int b_prio = get_sort_prio (b_data);

    if (a_prio > b_prio)
      return -1;
    if (a_prio < b_prio)
      return 1;

    if (is_set (a_data.display_name) && is_set (b_data.display_name))
      return a_data.display_name.collate (b_data.display_name);

    // Sort empty names last
    if (is_set (a_data.display_name))
      return -1;
    if (is_set (b_data.display_name))
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

  /* The hardcoded prio if set, otherwise 0 for the
     main/combined group, or -1 for the separated other group */
  private int get_sort_prio (ContactDataRow *data) {
    if (data->sort_prio != 0)
      return data->sort_prio;

    if (is_other (data))
      return -1;
    return 0;
  }

  public void set_show_subset (Subset subset) {
    show_subset = subset;
    update_all_filtered ();
    invalidate_filter ();
    invalidate_sort ();
  }

  public void set_custom_sort_prio (Contact c, int prio) {
    /* We use negative prios internally */
    assert (prio >= 0);

    var data = contacts.get (c);
    if (data == null)
      return;
    data.sort_prio = prio;
    data.changed ();
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

  private void update_data (ContactDataRow data) {
    var c = data.contact;
    data.display_name = c.display_name;
    data.initial_letter = c.initial_letter;
    data.filtered = calculate_filtered (c);

    data.update_widgets ();
  }

  private void update_all_filtered () {
    foreach (var data in contacts.values) {
      data.filtered = calculate_filtered (data.contact);
    }
  }

  private void contact_changed_cb (Store store, Contact c) {
    var data = contacts.get (c);
    update_data (data);
    data.changed();
  }

  private void contact_added_cb (Store store, Contact c) {
    var data =  new ContactDataRow(c);

    update_data (data);

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

  public override void row_selected (ListBoxRow row) {
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

  private void update_header (ListBoxRow row,
			      ListBoxRow? before_row) {
    var row_data = row as ContactDataRow;
    var before_data = before_row as ContactDataRow;

    var current = row.get_header ();

    if (before_data == null && row_data.sort_prio > 0) {
      if (current == null ||
	  !(current.get_data<bool> ("contacts-suggestions-header"))) {
	var l = new Label ("");
	l.set_data ("contacts-suggestions-header", true);
	l.set_markup (Markup.printf_escaped ("<b>%s</b>", _("Suggestions")));
	l.set_halign (Align.START);
	row.set_header (l);
      }
      return;
    }

    if (before_data != null && before_data.sort_prio > 0 &&
	row_data.sort_prio == 0) {
      if (current == null ||
	  !(current.get_data<bool> ("contacts-rest-header"))) {
	var l = new Label ("");
	l.set_data ("contacts-rest-header", true);
	l.set_halign (Align.START);
	row.set_header (l);
      }
      return;
    }

    if (is_other (row_data) &&
	(before_data == null || !is_other (before_data))) {
      if (current == null ||
	  !(current.get_data<bool> ("contacts-other-header"))) {
	var l = new Label ("");
	l.set_data ("contacts-other-header", true);
	l.set_markup (Markup.printf_escaped ("<b>%s</b>", _("Other Contacts")));
	l.set_halign (Align.START);
	row.set_header (l);
      }
      return;
    }

    if (before_data != null) {
      if (current == null || !(current is Separator))
	row.set_header (new Separator (Orientation.HORIZONTAL));
      return;
    }
    row.set_header (null);
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
