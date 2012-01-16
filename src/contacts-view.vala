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

public class Contacts.View : GLib.Object {
  private class ContactData {
    public Contact contact;
    public TreeIter iter;
    public bool visible;
    public bool is_first;
    public int sort_prio;
  }

  public enum Subset {
    PRIMARY,
    NON_PRIMARY,
    ALL_SEPARATED,
    ALL
  }

  Store contacts_store;
  Subset show_subset;
  ListStore list_store;
  HashSet<Contact> hidden_contacts;
  string []? filter_values;
  int custom_visible_count;
  ContactData suggestions_header_data;
  ContactData padding_data;
  ContactData other_header_data;

  public View (Store store) {
    contacts_store = store;
    hidden_contacts = new HashSet<Contact>();
    show_subset = Subset.ALL;

    list_store = new ListStore (2, typeof (Contact), typeof (ContactData *));
    suggestions_header_data = new ContactData ();
    suggestions_header_data.sort_prio = int.MAX;
    padding_data = new ContactData ();
    padding_data.sort_prio = 1;

    other_header_data = new ContactData ();
    other_header_data.sort_prio = -1;

    list_store.set_sort_func (0, (model, iter_a, iter_b) => {
	ContactData *aa, bb;
	model.get (iter_a, 1, out aa);
	model.get (iter_b, 1, out bb);

	int a_prio = get_sort_prio (aa);
	int b_prio = get_sort_prio (bb);

	if (a_prio > b_prio)
	    return -1;
	if (a_prio < b_prio)
	    return 1;

	var a = aa->contact;
	var b = bb->contact;

	if (is_set (a.display_name) && is_set (b.display_name))
	  return a.display_name.collate (b.display_name);

	// Sort empty names last
	if (is_set (a.display_name))
	  return -1;
	if (is_set (b.display_name))
	  return 1;

	return 0;
      });
    list_store.set_sort_column_id (0, SortType.ASCENDING);

    contacts_store.added.connect (contact_added_cb);
    contacts_store.removed.connect (contact_removed_cb);
    contacts_store.changed.connect (contact_changed_cb);
    foreach (var c in store.get_contacts ())
      contact_added_cb (store, c);
  }

  private int get_sort_prio (ContactData *data) {
    if (data->sort_prio != 0)
      return data->sort_prio;

    if (show_subset == Subset.ALL_SEPARATED &&
	!data->contact.is_primary)
      return -2;
    return 0;
  }

  public string get_header_text (TreeIter iter) {
    ContactData *data;
    model.get (iter, 1, out data);
    if (data == suggestions_header_data) {
      /* Translators: This is the header for the list of suggested contacts to
	 link to the current contact */
      return ngettext ("Suggestion", "Suggestions", custom_visible_count);
    }
    if (data == other_header_data) {
      /* Translators: This is the header for the list of suggested contacts to
	 link to the current contact */
      return _("Other Contacts");
    }
    return "";
  }

  public void set_show_subset (Subset subset) {
    show_subset = subset;

    bool new_visible = show_subset == Subset.ALL_SEPARATED;
    if (new_visible && !other_header_data.visible) {
      other_header_data.visible = true;
      list_store.append (out other_header_data.iter);
      list_store.set (other_header_data.iter, 1, other_header_data);
    }
    if (!new_visible && other_header_data.visible) {
      other_header_data.visible = false;
      list_store.remove (other_header_data.iter);
    }

    refilter ();
  }

  public void set_custom_sort_prio (Contact c, int prio) {
    /* We use negative prios internally */
    assert (prio >= 0);

    var data = lookup_data (c);
    // We insert a priority between 0 and 1 for the padding
    if (prio > 0)
      prio += 1;
    data.sort_prio = prio;
    contact_changed_cb (contacts_store, c);

    if (data.visible) {
      if (prio > 0) {
	if (custom_visible_count++ == 0)
	  add_custom_headers ();
      } else {
	if (custom_visible_count-- == 1)
	  remove_custom_headers ();
      }
    }
  }

  public TreeModel model { get { return list_store; } }

  private bool apply_filter (Contact contact) {
    if (contact.is_hidden)
      return false;

    if (contact in hidden_contacts)
      return false;

    if ((show_subset == Subset.PRIMARY &&
	 !contact.is_primary) ||
	(show_subset == Subset.NON_PRIMARY &&
	 contact.is_primary))
      return false;

    if (filter_values == null || filter_values.length == 0)
      return true;

    return contact.contains_strings (filter_values);
  }

  public bool is_first (TreeIter iter) {
    ContactData *data;
    list_store.get (iter, 1, out data);
    if (data != null)
      return data->is_first;
    return false;
  }

  private ContactData? get_previous (ContactData data) {
    ContactData *previous = null;
    TreeIter iter = data.iter;
    if (list_store.iter_previous (ref iter))
      list_store.get (iter, 1, out previous);
    return previous;
  }

  private ContactData? get_next (ContactData data) {
    ContactData *next = null;
    TreeIter iter = data.iter;
    if (list_store.iter_next (ref iter))
      list_store.get (iter, 1, out next);
    return next;
  }

  private void row_changed_no_resort (ContactData data) {
    var path = list_store.get_path (data.iter);
    list_store.row_changed (path, data.iter);
  }

  private void row_changed_resort (ContactData data) {
    list_store.set (data.iter, 0, data.contact);
  }

  private bool update_is_first (ContactData data, ContactData? previous) {
    bool old_is_first = data.is_first;

    bool is_custom = data.sort_prio != 0;
    bool previous_is_custom = previous != null && (previous.sort_prio != 0) ;

    if (is_custom) {
      data.is_first = false;
    } else if (previous != null && !previous_is_custom) {
      unichar previous_initial = previous.contact.initial_letter;
      unichar initial = data.contact.initial_letter;
      data.is_first = previous_initial != initial;
    } else {
      data.is_first = true;
    }

    if (old_is_first != data.is_first) {
      row_changed_no_resort (data);
      return true;
    }

    return false;
  }

  private void add_custom_headers () {
    suggestions_header_data.visible = true;
    list_store.append (out suggestions_header_data.iter);
    list_store.set (suggestions_header_data.iter, 1, suggestions_header_data);
    padding_data.visible = true;
    list_store.append (out padding_data.iter);
    list_store.set (padding_data.iter, 1, padding_data);
  }

  private void remove_custom_headers () {
    suggestions_header_data.visible = false;
    list_store.remove (suggestions_header_data.iter);
    padding_data.visible = false;
    list_store.remove (padding_data.iter);
  }

  private void add_to_model (ContactData data) {
    list_store.append (out data.iter);
    list_store.set (data.iter, 0, data.contact, 1, data);

    if  (data.sort_prio > 0) {
      if (custom_visible_count++ == 0)
	add_custom_headers ();
    }

    if (update_is_first (data, get_previous (data)) && data.is_first) {
      /* The newly added row is first, the next one might not be anymore */
      var next = get_next (data);
      if (next != null)
	update_is_first (next, data);
    }
  }

  private void remove_from_model (ContactData data) {
    if( data.sort_prio > 0) {
      if (custom_visible_count-- == 1)
	remove_custom_headers ();
    }

    ContactData? next = null;
    if (data.is_first)
      next = get_next (data);

    list_store.remove (data.iter);
    data.is_first = false;

    if (next != null)
      update_is_first (next, get_previous (next));
  }

  private void update_visible (ContactData data) {
    bool was_visible = data.visible;
    data.visible = apply_filter (data.contact);

    if (!was_visible && data.visible)
      add_to_model (data);

    if (was_visible && !data.visible)
      remove_from_model (data);
  }

  private void refilter () {
    foreach (var c in contacts_store.get_contacts ()) {
      update_visible (lookup_data (c));
    }
  }

  public void hide_contact (Contact contact) {
    hidden_contacts.add (contact);
    refilter ();
  }

  public void set_filter_values (string []? values) {
    filter_values = values;
    refilter ();
  }

  private void contact_changed_cb (Store store, Contact c) {
    ContactData data = lookup_data (c);

    bool was_visible = data.visible;

    ContactData? next = null;
    if (data.visible)
      next = get_next (data);

    update_visible (data);

    if (was_visible && data.visible) {
      /* We just moved position in the list while visible */

      row_changed_resort (data);

      /* Update the is_first on the previous next row */
      if (next != null)
	update_is_first (next, get_previous (next));

      /* Update the is_first on the new next row */
      next = get_next (data);
      if (next != null)
	update_is_first (next, data);
    }
  }

  private ContactData lookup_data (Contact c) {
    return c.lookup<ContactData> (this);
  }

  private void contact_added_cb (Store store, Contact c) {
    ContactData data =  new ContactData();
    data.contact = c;
    data.visible = false;

    c.set_lookup (this, data);

    update_visible (data);
  }

  private void contact_removed_cb (Store store, Contact c) {
    var data = lookup_data (c);

    if (data.visible)
      remove_from_model (data);

    c.remove_lookup<ContactData> (this);
  }

  public bool lookup_iter (Contact c, out TreeIter iter) {
    var data = lookup_data (c);
    iter = data.iter;
    return data.visible;
  }
}


public class Contacts.ViewWidget : TreeView {
  public View view;
  private CellRendererShape shape;
  public enum TextDisplay {
    NONE,
    PRESENCE,
    STORES
  }
  private TextDisplay text_display;

  public signal void selection_changed (Contact? contact);

  public ViewWidget (View view, TextDisplay text_display = TextDisplay.PRESENCE) {
    this.view = view;
    this.text_display = text_display;

    set_model (view.model);
    set_headers_visible (false);

    var selection = get_selection ();
    selection.set_mode (SelectionMode.BROWSE);
    selection.set_select_function ( (selection, model, path, path_currently_selected) => {
	Contact contact;
	TreeIter iter;
	model.get_iter (out iter, path);
	view.model.get (iter, 0, out contact);
	return contact != null;
      });
    selection.changed.connect (contacts_selection_changed);

    var column = new TreeViewColumn ();

    var text = new CellRendererText ();
    text.set_alignment (0, 0);
    column.pack_start (text, false);
    text.set ("weight", Pango.Weight.BOLD, "scale", 1.28, "width", 24);
    column.set_cell_data_func (text, (column, cell, model, iter) => {
	string letter = "";
	if (view.is_first (iter)) {
	  Contact contact;
	  view.model.get (iter, 0, out contact);
	  letter = contact.initial_letter.to_string ();
	}

	cell.set ("text", letter);
	if (letter != "") {
	  cell.height = -1;
	} else {
	  cell.height = 1;
	}
      });

    var icon = new CellRendererPixbuf ();
    icon.xalign = 0.0f;
    icon.yalign = 0.0f;
    icon.width = 48 + 2;
    column.pack_start (icon, false);
    column.set_cell_data_func (icon, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);

	if (contact == null) {
	  cell.visible = false;
	  return;
	}
	cell.visible = true;

	if (contact != null)
	  cell.set ("pixbuf", contact.small_avatar);
	else
	  cell.set ("pixbuf", null);
      });

    shape = new CellRendererShape ();
    shape.set_padding (4, 0);

    Pango.cairo_context_set_shape_renderer (get_pango_context (), shape.render_shape);

    column.pack_start (shape, true);
    column.set_cell_data_func (shape, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);

	if (contact == null) {
	  cell.visible = false;
	  return;
	}
	cell.visible = true;

	var name = contact.display_name;
	switch (text_display) {
	default:
	case TextDisplay.NONE:
	  cell.set ("name", name,
		    "show_presence", false,
		    "message", "");
	  break;
	case TextDisplay.PRESENCE:
	  cell.set ("name", name,
		    "show_presence", true,
		    "presence", contact.presence_type,
		    "message", contact.presence_message,
		    "is_phone", contact.is_phone);
	  break;
	case TextDisplay.STORES:
	  string stores = "";
	  bool first = true;
	  foreach (var p in contact.individual.personas) {
	    if (!first)
	      stores += ", ";
	    stores += Contact.format_persona_store_name (p.store);
	    first = false;
	  }
	  cell.set ("name", name,
		    "show_presence", false,
		    "message", stores);
	  break;
	}
      });


    text = new CellRendererText ();
    text.set_alignment (0, 0);
    column.pack_start (text, true);
    text.set ("weight", Pango.Weight.BOLD);
    column.set_cell_data_func (text, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);
	cell.visible = contact == null;
	if (cell.visible) {
	  string header = view.get_header_text (iter);
	  cell.set ("text", header);
	  if (header == "")
	    cell.height = 6; // PADDING
	  else
	    cell.height = -1;
	}
      });

    append_column (column);
  }

  private void contacts_selection_changed (TreeSelection selection) {
    TreeIter iter;
    TreeModel model;

    Contact? contact = null;
    if (selection.get_selected (out model, out iter)) {
      model.get (iter, 0, out contact);
    }

    selection_changed (contact);
  }

  public void select_contact (Contact contact) {
    TreeIter iter;
    if (view.lookup_iter (contact, out iter)) {
      get_selection ().select_iter (iter);
      scroll_to_cell (view.model.get_path (iter),
		      null, true, 0.0f, 0.0f);
    }
  }
}
