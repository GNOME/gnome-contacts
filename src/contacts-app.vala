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

public class Contacts.App : Window {
  private ListStore group_store;

  private enum GroupColumns {
    TEXT,
    IS_HEADER,
    N_COLUMNS
  }

  private enum ContactColumns {
    ICON,
    NAME,
    IS_HEADER,
    N_COLUMNS
  }

  private void setup_group_view (TreeView tree_view) {
    tree_view.set_headers_visible (false);

    var selection = tree_view.get_selection ();
    selection.set_mode (SelectionMode.BROWSE);
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
    group_store.set (iter, GroupColumns.IS_HEADER, true, GroupColumns.TEXT, "Groups");
    group_store.append (out iter);
    group_store.set (iter, GroupColumns.IS_HEADER, false, GroupColumns.TEXT, "All");
    group_store.append (out iter);
    group_store.set (iter, GroupColumns.IS_HEADER, false, GroupColumns.TEXT, "Personal");
    group_store.append (out iter);
    group_store.set (iter, GroupColumns.IS_HEADER, false, GroupColumns.TEXT, "Work");
  }
  
  private Gdk.Pixbuf lookup_icon(Widget widget, string icon_name) {
    var context = widget.get_style_context ();
    context.save ();

    context.add_class (STYLE_CLASS_INFO);

    Gdk.Pixbuf icon = null;
    var icon_info = IconTheme.get_default ().lookup_icon (icon_name, 16, 
							  IconLookupFlags.GENERIC_FALLBACK);

    try {
      // vapi file broken, so this is commented out and we do a pure load_icon instead:
      //Gdk.RGBA color;
      //context.get_background_color (StateFlags.NORMAL, out color);
      // var icon = icon_info.load_symbolic (color, null, null, null, null);

      icon = icon_info.load_icon ();
    } catch {
    }

    context.restore ();

    return icon;
  }

  public App() {
    set_title (_("Contacts"));
    set_default_size (300, 200);
    this.destroy.connect (Gtk.main_quit);

    var grid = new Grid();
    add (grid);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_vexpand (true);
    grid.attach (scrolled, 0, 0, 1, 2);

    scrolled.get_style_context ().add_class (STYLE_CLASS_SIDEBAR);

    group_store = new ListStore(GroupColumns.N_COLUMNS,
				typeof (string), typeof (bool));
    fill_group_model ();

    var tree_view = new TreeView.with_model (group_store);
    setup_group_view (tree_view);
    scrolled.add(tree_view);

    var toolbar = new Toolbar ();

    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_vexpand (false);
    var groups_button = new ToggleToolButton ();
    groups_button.set_icon_widget (new Image.from_pixbuf (lookup_icon (toolbar, "list-add-symbolic")));
    groups_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    groups_button.is_important = false;
    toolbar.add (groups_button);

    groups_button.get_style_context ().set_junction_sides (JunctionSides.LEFT);

    var favourite_button = new ToggleToolButton ();
    favourite_button.set_icon_widget (new Image.from_pixbuf (lookup_icon (toolbar, "list-add-symbolic")));
    favourite_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    favourite_button.is_important = false;
    toolbar.add (favourite_button);
    favourite_button.get_style_context ().set_junction_sides (JunctionSides.RIGHT);

    var separator = new SeparatorToolItem ();
    separator.set_draw (false);
    toolbar.add (separator);

    var entry = new Entry ();
    entry.set_icon_from_pixbuf (EntryIconPosition.SECONDARY, lookup_icon (toolbar, "edit-find-symbolic"));

    var search_entry_item = new ToolItem ();
    search_entry_item.is_important = false;
    search_entry_item.set_expand (true);
    search_entry_item.add (entry);
    toolbar.add (search_entry_item);

    separator = new SeparatorToolItem ();
    separator.set_draw (false);
    toolbar.add (separator);

    var add_button = new ToolButton (new Image.from_pixbuf (lookup_icon (toolbar, "list-add-symbolic")), null);
    add_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    add_button.is_important = false;
    toolbar.add (add_button);

    grid.attach (toolbar, 1, 0, 1, 1);

    var label = new Label ("1111111111111222222222222221111111111111111111111111111111");
    label.vexpand = true;
    grid.attach (label, 1, 1, 1, 1);
    
    grid.show_all ();
  }
}