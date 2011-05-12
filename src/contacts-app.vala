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
  private ListStore group_store;
  private ContactStore contacts_store;
  private TreeModelFilter filter_model;
  private Entry filter_entry;
  string []? filter_values;
  bool filter_favourites;
  string? filter_group;
  Widget sidebar;
  TreeView group_tree_view;
  TreeView contacts_tree_view;

  public IndividualAggregator aggregator { get; private set; }
  public BackendStore backend_store { get; private set; }

  private enum GroupColumns {
    TEXT,
    GROUP,
    IS_HEADER,
    N_COLUMNS
  }

  private void setup_group_view (TreeView tree_view) {
    tree_view.set_headers_visible (false);

    var selection = tree_view.get_selection ();
    selection.set_mode (SelectionMode.BROWSE);
    selection.select_path (new TreePath.from_indices(0));
    selection.changed.connect (group_selected_changed);
    selection.set_select_function ((selection, model, path, path_currently_selected) => {
	TreeIter iter;
	bool is_header;
	model.get_iter (out iter, path);
	model.get (iter, GroupColumns.IS_HEADER, out is_header, -1);
	return !is_header;
      });

    var column = new TreeViewColumn ();
    var text = new CellRendererText ();
    column.pack_start (text, true);
    column.add_attribute (text, "text", GroupColumns.TEXT);
    column.set_cell_data_func (text, (column, cell, model, iter) => {
	bool is_header;

	model.get (iter, GroupColumns.IS_HEADER, out is_header, -1);
	cell.set ("visible", !is_header);
      });

    text = new CellRendererText ();
    column.pack_start (text, true);
    column.add_attribute (text, "text", GroupColumns.TEXT);
    column.add_attribute (text, "visible", GroupColumns.IS_HEADER);
    text.set ("weight", Pango.Weight.BOLD);

    tree_view.append_column (column);
  }

  private void fill_group_model () {
    TreeIter iter;
    group_store.append (out iter);
    group_store.set (iter, GroupColumns.IS_HEADER, false, GroupColumns.TEXT, "All contacts", GroupColumns.GROUP, null);
    group_store.append (out iter);
    group_store.set (iter, GroupColumns.IS_HEADER, false, GroupColumns.TEXT, "Personal", GroupColumns.GROUP, "Gnome");
    group_store.append (out iter);
    group_store.set (iter, GroupColumns.IS_HEADER, false, GroupColumns.TEXT, "Work", GroupColumns.GROUP, "Buddies");
  }

  private void setup_contacts_view (TreeView tree_view) {
    tree_view.set_headers_visible (false);

    var selection = tree_view.get_selection ();
    selection.set_mode (SelectionMode.BROWSE);

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

	string? alias = contact.individual.alias;
	cell.set ("text", alias);
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

    if (filter_group != null) {
      if (!(filter_group in contact.individual.groups))
	return false;
    }

    if (filter_values == null || filter_values.length == 0)
      return true;

    return contact.contains_strings (filter_values);
  }

  private void group_selected_changed (TreeSelection selection) {
    TreeIter iter;

    if (selection.get_selected (null, out iter)) {
      string? group;
      group_store.get (iter, GroupColumns.GROUP, out group);
      filter_group = group;
      filter_model.refilter ();
    }
  }

  private void groups_button_toggled (ToggleToolButton toggle_button) {
    if (toggle_button.get_active ()) {
      sidebar.show ();
    } else {
      sidebar.hide ();
      group_tree_view.get_selection ().select_path (new TreePath.from_indices(0));
    }
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

    var scrolled = new ScrolledWindow(null, null);
    sidebar = scrolled;
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_border_width (8);
    grid.attach (scrolled, 0, 0, 1, 2);

    scrolled.get_style_context ().add_class (STYLE_CLASS_SIDEBAR);

    group_store = new ListStore(GroupColumns.N_COLUMNS,
				typeof (string), typeof (string), typeof (bool));
    fill_group_model ();

    group_tree_view = new TreeView.with_model (group_store);
    setup_group_view (group_tree_view);
    scrolled.add(group_tree_view);

    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_vexpand (false);
    var groups_button = new ToggleToolButton ();

    groups_button.set_icon_name ("system-users-symbolic");
    groups_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    groups_button.is_important = false;
    toolbar.add (groups_button);
    groups_button.toggled.connect (groups_button_toggled);
    groups_button.set_active (true);

    groups_button.get_style_context ().set_junction_sides (JunctionSides.LEFT);

    var favourite_button = new ToggleToolButton ();
    favourite_button.set_icon_name ("user-bookmarks-symbolic");
    favourite_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    favourite_button.is_important = false;
    toolbar.add (favourite_button);
    favourite_button.get_style_context ().set_junction_sides (JunctionSides.RIGHT);
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

    scrolled = new ScrolledWindow(null, null);
    scrolled.set_min_content_width (340);
    scrolled.set_vexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.get_style_context ().set_junction_sides (JunctionSides.RIGHT | JunctionSides.LEFT | JunctionSides.TOP);

    var frame = new Frame (null);
    var grid2 = new Grid ();
    frame.add (grid2);

    grid2.attach (toolbar, 0, 0, 1, 1);
    grid2.attach (scrolled, 0, 1, 1, 1);
    grid.attach (frame, 1, 0, 1, 2);

    var ebox = new EventBox ();
    Gdk.RGBA white = {1, 1, 1, 1};
    ebox.override_background_color (0, white);
    ebox.set_hexpand (true);
    grid.attach (ebox, 2, 0, 1, 2);

    var vbox = new Box (Orientation.VERTICAL, 0);
    vbox.set_border_width (10);
    ebox.add (vbox);
    vbox.set_hexpand (true);
    vbox.set_vexpand (true);

    var hbox = new Box (Orientation.HORIZONTAL, 10);
    vbox.pack_end (hbox, false, false, 0);

    var bbox = new ButtonBox (Orientation.HORIZONTAL);
    bbox.set_layout (ButtonBoxStyle.START);
    hbox.pack_start (bbox, true, true, 0);

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
