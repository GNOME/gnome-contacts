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

public class Contacts.ListPane : Frame {
  private Store contacts_store;
  private TreeView contacts_tree_view;
  public Entry filter_entry;
  private uint filter_entry_changed_id;

  public IndividualAggregator aggregator { get; private set; }
  public BackendStore backend_store { get; private set; }

  public signal void selection_changed (Contact? contact);
  public signal void create_new ();

  private void setup_contacts_view (TreeView tree_view) {
    tree_view.set_headers_visible (false);

    var selection = tree_view.get_selection ();
    selection.set_mode (SelectionMode.BROWSE);
    selection.changed.connect (contacts_selection_changed);

    var column = new TreeViewColumn ();

    var text = new CellRendererText ();
    text.set_alignment (0, 0);
    column.pack_start (text, true);
    text.set ("weight", Pango.Weight.BOLD, "scale", 1.28, "width", 24);
    column.set_cell_data_func (text, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);

	string letter = "";
	if (contacts_store.is_first (iter))
	  letter = contact.display_name.get_char ().totitle ().to_string ();
	cell.set ("text", letter);
      });

    var icon = new CellRendererPixbuf ();
    column.pack_start (icon, false);
    column.set_cell_data_func (icon, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);

	cell.set ("pixbuf", contact.avatar);
      });

    tree_view.append_column (column);

    column = new TreeViewColumn ();

    var area = (CellAreaBox)column.get_area ();
    area.set_orientation (Orientation.VERTICAL);

    text = new CellRendererText ();
    column.pack_start (text, false);
    text.set ("weight", Pango.Weight.BOLD, "wrap-width", 230);
    column.set_cell_data_func (text, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);

	string name = contact.display_name;
	cell.set ("text", name);
      });

    icon = new CellRendererPixbuf ();

    icon.set_alignment (0, 0.5f);
    column.pack_start (icon, false);
    column.set_cell_data_func (icon, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);
	Individual individual = contact.individual;

	string? iconname = Contact.presence_to_icon (individual.presence_type);
	if (icon != null)
	  cell.set ("icon-name", iconname);
	else
	  cell.set ("icon-name", null);

      });

    tree_view.append_column (column);
  }

  private void refilter () {
    string []? values;
    string str = filter_entry.get_text ();

    if (str.length == 0)
      values = null;
    else {
      str = str.casefold();
      values = str.split(" ");
    }

    contacts_store.set_filter_values (values);
  }

  private bool filter_entry_changed_timeout () {
    filter_entry_changed_id = 0;
    refilter ();
    return false;
  }

  private void filter_entry_changed (Editable editable) {
    if (filter_entry_changed_id != 0)
      Source.remove (filter_entry_changed_id);

    filter_entry_changed_id = Timeout.add (300, filter_entry_changed_timeout);
    
    if (filter_entry.get_text () == "")
      filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    else
      filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-clear-symbolic");
  }

  private void filter_entry_clear (EntryIconPosition position) {
    filter_entry.set_text ("");
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

  public ListPane () {
    contacts_store = new Store ();

    aggregator = new IndividualAggregator ();
    aggregator.individuals_changed.connect ((added, removed, m, a, r) =>   {
	foreach (Individual i in removed) {
	  contacts_store.remove (Contact.from_individual (i));
	}
	foreach (Individual i in added) {
	  var c = new Contact (i);
	  contacts_store.add (c);
	}
      });
    aggregator.prepare ();

    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);

    var separator = new SeparatorToolItem ();
    separator.set_draw (false);
    toolbar.add (separator);

    filter_entry = new Entry ();
    filter_entry.set ("placeholder-text", _("Type to search..."));
    filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    filter_entry.changed.connect (filter_entry_changed);
    filter_entry.icon_press.connect (filter_entry_clear);

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
    add_button.clicked.connect ( (button) => {
	create_new ();
      });

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_min_content_width (310);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.get_style_context ().set_junction_sides (JunctionSides.RIGHT | JunctionSides.LEFT | JunctionSides.TOP);

    var grid = new Grid ();
    this.add (grid);

    grid.attach (toolbar, 0, 0, 1, 1);
    grid.attach (scrolled, 0, 1, 1, 1);

    contacts_tree_view = new TreeView.with_model (contacts_store.model);
    setup_contacts_view (contacts_tree_view);
    scrolled.add (contacts_tree_view);

    this.show_all ();
  }
}
