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

public class Contacts.View : Contacts.Sorted {
  private class ContactData {
    public Contact contact;
    public Grid grid;
    public Label label;
    public ContactFrame image_frame;
    public int sort_prio;
    public string display_name;
    public unichar initial_letter;
    public bool filtered;
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

  Store contacts_store;
  Subset show_subset;
  HashMap<Contact,ContactData> contacts;
  HashSet<Contact> hidden_contacts;

  string []? filter_values;
  private TextDisplay text_display;

  public View (Store store, TextDisplay text_display = TextDisplay.PRESENCE) {
    set_selection_mode (SelectionMode.BROWSE);
    contacts_store = store;
    hidden_contacts = new HashSet<Contact>();
    show_subset = Subset.ALL;
    this.text_display = text_display;

    contacts = new HashMap<Contact,ContactData> ();

    this.set_sort_func ((widget_a, widget_b) => {
	var a = widget_a.get_data<ContactData> ("data");
	var b = widget_b.get_data<ContactData> ("data");
	return compare_data (a, b);
      });
    this.set_filter_func (filter);
    this.set_separator_funcs (update_separator);

    contacts_store.added.connect (contact_added_cb);
    contacts_store.removed.connect (contact_removed_cb);
    contacts_store.changed.connect (contact_changed_cb);
    foreach (var c in store.get_contacts ())
      contact_added_cb (store, c);
  }

  private int compare_data (ContactData a_data, ContactData b_data) {
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

  private bool is_other (ContactData data) {
    if (show_subset == Subset.ALL_SEPARATED &&
	data.contact != null &&
	!data.contact.is_main)
      return true;
    return false;
  }

  /* The hardcoded prio if set, otherwise 0 for the
     main/combined group, or -1 for the separated other group */
  private int get_sort_prio (ContactData *data) {
    if (data->sort_prio != 0)
      return data->sort_prio;

    if (is_other (data))
      return -1;
    return 0;
  }

  public void set_show_subset (Subset subset) {
    show_subset = subset;
    update_all_filtered ();
    refilter ();
    resort ();
  }

  public void set_custom_sort_prio (Contact c, int prio) {
    /* We use negative prios internally */
    assert (prio >= 0);

    var data = contacts.get (c);
    if (data == null)
      return;
    data.sort_prio = prio;
    child_changed (data.grid);
  }

  public void hide_contact (Contact contact) {
    hidden_contacts.add (contact);
    update_all_filtered ();
    refilter ();
  }

  public void set_filter_values (string []? values) {
    filter_values = values;
    update_all_filtered ();
    refilter ();
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

  private void update_data (ContactData data) {
    var c = data.contact;
    data.display_name = c.display_name;
    data.initial_letter = c.initial_letter;
    data.filtered = calculate_filtered (c);

    data.label.set_markup (Markup.printf_escaped ("<span font='16px'>%s</span>", data.display_name));
    data.image_frame.set_image (c.individual, c);
  }

  private void update_all_filtered () {
    foreach (var data in contacts.values) {
      data.filtered = calculate_filtered (data.contact);
    }
  }

  private void contact_changed_cb (Store store, Contact c) {
    var data = contacts.get (c);
    update_data (data);
    child_changed (data.grid);
  }

  private void contact_added_cb (Store store, Contact c) {
    var data =  new ContactData();
    data.contact = c;
    data.grid = new Grid ();
    data.grid.margin = 12;
    data.grid.set_column_spacing (10);
    data.image_frame = new ContactFrame (Contact.SMALL_AVATAR_SIZE);
    data.label = new Label ("");
    data.label.set_ellipsize (Pango.EllipsizeMode.END);
    data.label.set_valign (Align.START);
    data.label.set_halign (Align.START);

    data.grid.attach (data.image_frame, 0, 0, 1, 2);
    data.grid.attach (data.label, 1, 0, 1, 1);

    if (text_display == TextDisplay.PRESENCE) {
      var merged_presence = c.create_merged_presence_widget ();
      merged_presence.set_halign (Align.START);
      merged_presence.set_valign (Align.END);
      merged_presence.set_vexpand (false);
      merged_presence.set_margin_bottom (4);

      data.grid.attach (merged_presence,  1, 1, 1, 1);
    }

    if (text_display == TextDisplay.STORES) {
      var stores = new Label ("");
      stores.set_markup (Markup.printf_escaped ("<span font='12px'>%s</span>",
						c.format_persona_stores ()));

      stores.set_ellipsize (Pango.EllipsizeMode.END);
      stores.set_halign (Align.START);
      data.grid.attach (stores,  1, 1, 1, 1);
    }

    update_data (data);

    data.grid.set_data<ContactData> ("data", data);
    data.grid.show_all ();
    contacts.set (c, data);
    this.add (data.grid);
  }

  private void contact_removed_cb (Store store, Contact c) {
    var data = contacts.get (c);
    data.grid.destroy ();
    data.label.destroy ();
    data.image_frame.destroy ();
    contacts.unset (c);
  }

  public override void child_selected (Widget? child) {
    var data = child.get_data<ContactData> ("data");
    selection_changed (data != null ? data.contact : null);
  }

  private bool filter (Widget child) {
    var data = child.get_data<ContactData> ("data");

    return data.filtered;
  }

  private void update_separator (ref Widget? separator,
				 Widget widget,
				 Widget? before_widget) {
    var w_data = widget.get_data<ContactData> ("data");
    ContactData? before_data = null;
    if (before_widget != null)
      before_data = before_widget.get_data<ContactData> ("data");

    if (before_data == null && w_data.sort_prio > 0) {
      if (separator == null ||
	  !(separator.get_data<bool> ("contacts-suggestions-header"))) {
	var l = new Label ("");
	l.set_data ("contacts-suggestions-header", true);
	l.set_markup (Markup.printf_escaped ("<b>%s</b>", _("Suggestions")));
	l.set_halign (Align.START);
	separator = l;
      }
      return;
    }

    if (before_data != null && before_data.sort_prio > 0 &&
	w_data.sort_prio == 0) {
      if (separator == null ||
	  !(separator.get_data<bool> ("contacts-rest-header"))) {
	var l = new Label ("");
	l.set_data ("contacts-rest-header", true);
	l.set_halign (Align.START);
	separator = l;
      }
      return;
    }

    if (is_other (w_data) &&
	(before_data == null || !is_other (before_data))) {
      if (separator == null ||
	  !(separator.get_data<bool> ("contacts-other-header"))) {
	var l = new Label ("");
	l.set_data ("contacts-other-header", true);
	l.set_markup (Markup.printf_escaped ("<b>%s</b>", _("Other Contacts")));
	l.set_halign (Align.START);
	separator = l;
      }
      return;
    }

    if (before_data != null &&
	w_data.initial_letter != before_data.initial_letter) {
      if (separator == null || !(separator is Separator))
	separator = new Separator (Orientation.HORIZONTAL);
      return;
    }
    separator = null;
  }
}
