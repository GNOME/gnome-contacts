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
  private ContactStore contacts_store;
  private TreeModelFilter filter_model;
  private Entry filter_entry;
  string []? filter_values;
  bool filter_favourites;
  TreeView contacts_tree_view;
  Grid fields_grid;
  Grid card_grid;
  SizeGroup label_size_group;

  public IndividualAggregator aggregator { get; private set; }
  public BackendStore backend_store { get; private set; }

  private void setup_contacts_view (TreeView tree_view) {
    tree_view.set_headers_visible (false);

    var selection = tree_view.get_selection ();
    selection.set_mode (SelectionMode.BROWSE);
    selection.changed.connect (contacts_selected_changed);

    var column = new TreeViewColumn ();
    column.set_spacing (10);

    var icon = new CellRendererPixbuf ();
    column.pack_start (icon, false);
    column.set_cell_data_func (icon, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);

	cell.set ("pixbuf", contact.avatar);
      });

    var text = new CellRendererText ();
    column.pack_start (text, true);
    text.set ("weight", Pango.Weight.BOLD);
    column.set_cell_data_func (text, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);

	string name = contact.display_name;
	cell.set ("text", name);
      });

    icon = new CellRendererPixbuf ();
    column.pack_start (icon, false);
    column.set_cell_data_func (icon, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);
	Individual individual = contact.individual;

	string? iconname = null;
	switch (individual.presence_type) {
	case PresenceType.AVAILABLE:
	case PresenceType.UNKNOWN:
	  iconname = "user-available-symbolic";
	  break;
	case PresenceType.AWAY:
	case PresenceType.EXTENDED_AWAY:
	  iconname = "user-away-symbolic";
	  break;
	case PresenceType.BUSY:
	  iconname = "user-busy-symbolic";
	  break;
	}
	cell.set ("visible", icon != null);
	if (icon != null)
	  cell.set ("icon-name", iconname);
      });

    tree_view.append_column (column);
  }

  private bool filter_row (TreeModel model,
			   TreeIter iter) {
    Contact contact;

    model.get (iter, 0, out contact);

    if (contact == null)
      return false;

    if (filter_favourites && !contact.individual.is_favourite)
      return false;

    if (filter_values == null || filter_values.length == 0)
      return true;

    return contact.contains_strings (filter_values);
  }

  private void favourites_button_toggled (ToggleToolButton toggle_button) {
    filter_favourites = toggle_button.get_active ();
    filter_model.refilter ();
  }

  private void filter_entry_changed (Editable editable) {
    string []? values;
    string str = filter_entry.get_text ();

    if (str.length == 0)
      values = null;
    else {
      str = str.casefold();
      values = str.split(" ");
    }

    filter_values = values;
    filter_model.refilter ();
  }

  private Grid add_label (string label, bool is_clickable) {
    var grid = new Grid ();
    grid.set_row_spacing (8);
    grid.set_orientation (Orientation.HORIZONTAL);
    var l = new Label (label);
    label_size_group.add_widget (l);
    l.get_style_context ().add_class ("dim-label");
    l.set_alignment (1, 0.5f);
    grid.add (l);
    if (is_clickable) {
      var clickable = new Contacts.Clickable ();
      clickable.set_hexpand (true);
      clickable.add (grid);
      fields_grid.add (clickable);
    } else {
      fields_grid.add (grid);
    }

    return grid;
  }

  private void add_string_label (Contact contact, string label, string pname) {
    Value prop_value;
    prop_value = Value (typeof (string));
    contact.individual.get_property (pname, ref prop_value);
    string val = prop_value.get_string ();

    if (val != null) {
      var grid = add_label(label, true);
      var v = new Label (val);
      v.set_valign (Align.CENTER);
      v.set_halign (Align.START);
      grid.add (v);
    }
  }

  private void display_contact (Contact contact) {

    var image_frame = new Frame (null);
    label_size_group.add_widget (image_frame);
    image_frame.get_style_context ().add_class ("contactframe");
    image_frame.set_shadow_type (ShadowType.OUT);
    var image = new Image ();
    image.set_size_request (100, 100);
    image_frame.add (image);

    Gdk.Pixbuf pixbuf = null;

    if (contact.individual.avatar != null &&
	contact.individual.avatar.get_path () != null) {
      try {
	pixbuf = new Gdk.Pixbuf.from_file_at_scale (contact.individual.avatar.get_path (), 100, 100, true);
      }
      catch {
      }
    }

    if (pixbuf == null) {
      /* TODO: Set fallback image */
    }

    if (pixbuf != null) {
	image.set_from_pixbuf (pixbuf);
    }

    card_grid.attach (image_frame, 0, 0, 1, 1);

    var g = new Grid ();
    card_grid.attach (g, 1, 0, 1, 1);

    var l = new Label (null);
    l.set_markup ("<big><b>" + contact.display_name + "</b></big>");
    l.set_hexpand (true);
    l.set_halign (Align.START);
    g.attach (l,  1, 0, 1, 1);
    l = new Label ("\xE2\x80\x9Cnick\xE2\x80\x9D");
    l.set_halign (Align.START);
    g.attach (l,  1, 1, 1, 1);
    l = new Label ("Consultant, Company Inc");
    l.set_halign (Align.START);
    g.attach (l,  1, 2, 1, 1);

    var starred = new StarredButton ();
    starred.set_active (contact.individual.is_favourite);
    starred.set_hexpand (false);
    starred.set_vexpand (false);
    starred.set_valign (Align.START);
    card_grid.attach (starred, 2, 0, 1, 1);

    add_string_label (contact, _("Alias"), "alias");
    add_string_label (contact, _("Alias again"), "alias");
    add_string_label (contact, _("Alias again"), "alias");
    add_string_label (contact, _("Alias again"), "alias");
    add_string_label (contact, _("Alias again"), "alias");
    add_string_label (contact, _("Alias again"), "alias");
    add_string_label (contact, _("Full name"), "full-name");

    card_grid.show_all ();
    fields_grid.show_all ();
  }

  private void contacts_selected_changed (TreeSelection selection) {
    TreeIter iter;
    TreeModel model;

    if (selection.get_selected (out model, out iter)) {
      Contact contact;
      model.get (iter, 0, out contact);
      foreach (var w in card_grid.get_children ()) {
	w.destroy ();
      }
      foreach (var w in fields_grid.get_children ()) {
	w.destroy ();
      }
      if (contact != null) {
	display_contact (contact);
      }
    }
  }


  public App () {
    contacts_store = new ContactStore ();
    filter_model = new TreeModelFilter (contacts_store, null);
    filter_model.set_visible_func (filter_row);

    aggregator = new IndividualAggregator ();
    aggregator.individuals_changed.connect ((added, removed, m, a, r) =>   {
	foreach (Individual i in removed) {
	  contacts_store.remove_individual (i);
	}
	foreach (Individual i in added) {
	  contacts_store.insert_individual (i);
	}
      });
    aggregator.prepare ();

    set_title (_("Contacts"));
    set_default_size (800, 500);
    this.destroy.connect (Gtk.main_quit);

    var grid = new Grid();
    add (grid);

    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_vexpand (false);

    var favourite_button = new ToggleToolButton ();
    favourite_button.set_icon_name ("user-bookmarks-symbolic");
    favourite_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    favourite_button.is_important = false;
    toolbar.add (favourite_button);
    favourite_button.toggled.connect (favourites_button_toggled);

    var separator = new SeparatorToolItem ();
    separator.set_draw (false);
    toolbar.add (separator);

    filter_entry = new Entry ();
    filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    filter_entry.changed.connect (filter_entry_changed);

    map_event.connect (() => {
	filter_entry.grab_focus ();
	return true;
      });

    var search_entry_item = new ToolItem ();
    search_entry_item.is_important = false;
    search_entry_item.set_expand (true);
    search_entry_item.add (filter_entry);
    toolbar.add (search_entry_item);

    separator = new SeparatorToolItem ();
    separator.set_draw (false);
    toolbar.add (separator);

    var add_button = new ToolButton (null, null);
    add_button.set_icon_name ("list-add-symbolic");
    add_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    add_button.is_important = false;
    toolbar.add (add_button);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_min_content_width (340);
    scrolled.set_vexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.get_style_context ().set_junction_sides (JunctionSides.RIGHT | JunctionSides.LEFT | JunctionSides.TOP);

    var frame = new Frame (null);
    var middle_grid = new Grid ();
    frame.add (middle_grid);

    middle_grid.attach (toolbar, 0, 0, 1, 1);
    middle_grid.attach (scrolled, 0, 1, 1, 1);
    grid.attach (frame, 0, 0, 1, 2);

    var ebox = new EventBox ();
    ebox.set_hexpand (true);
    grid.attach (ebox, 1, 0, 1, 2);

    var right_grid = new Grid ();
    right_grid.set_border_width (10);
    ebox.add (right_grid);

    label_size_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
    card_grid = new Grid ();
    card_grid.set_row_spacing (8);

    right_grid.attach (card_grid, 0, 0, 1, 1);

    var fields_scrolled = new ScrolledWindow (null, null);
    fields_scrolled.set_hexpand (true);
    fields_scrolled.set_vexpand (true);
    fields_grid = new Grid ();
    fields_grid.set_orientation (Orientation.VERTICAL);
    fields_scrolled.add_with_viewport (fields_grid);

    right_grid.attach (fields_scrolled, 0, 1, 1, 1);

    var bbox = new ButtonBox (Orientation.HORIZONTAL);
    bbox.set_layout (ButtonBoxStyle.START);
    right_grid.attach (bbox, 0, 2, 1, 1);

    var button = new Button.with_label(_("Notes"));
    bbox.pack_start (button, false, false, 0);
    button = new Button.with_label(_("Edit"));
    bbox.pack_start (button, false, false, 0);

    button = new Button ();
    var label = new Label (_("More"));
    var arrow = new Arrow (ArrowType.DOWN, ShadowType.NONE);
    var hbox2 = new Box (Orientation.HORIZONTAL, 0);
    hbox2.pack_start (label, true, false, 0);
    hbox2.pack_start (arrow, false, false, 0);
    button.add (hbox2);
    bbox.pack_end (button, false, false, 0);
    bbox.set_child_secondary (button, true);

    contacts_tree_view = new TreeView.with_model (filter_model);
    setup_contacts_view (contacts_tree_view);
    scrolled.add (contacts_tree_view);

    grid.show_all ();
  }
}
