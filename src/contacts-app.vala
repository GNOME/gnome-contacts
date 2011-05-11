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
  protected class IndividualData  {
    public TreeIter iter;
    public Gdk.Pixbuf? avatar;
  }
  private ListStore group_store;
  private ListStore contacts_store;

  public IndividualAggregator aggregator { get; private set; }
  public BackendStore backend_store { get; private set; }
  Gdk.Pixbuf fallback_avatar;

  private enum GroupColumns {
    TEXT,
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

  private void round_rect (Cairo.Context cr, int x, int y, int w, int h, int r) {
    cr.move_to(x+r,y);
    cr.line_to(x+w-r,y);
    cr.curve_to(x+w,y,x+w,y,x+w,y+r);
    cr.line_to(x+w,y+h-r);
    cr.curve_to(x+w,y+h,x+w,y+h,x+w-r,y+h);
    cr.line_to(x+r,y+h);
    cr.curve_to(x,y+h,x,y+h,x,y+h-r);
    cr.line_to(x,y+r);
    cr.curve_to(x,y,x,y,x+r,y);
  }

  private Gdk.Pixbuf draw_fallback_avatar () {
    var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, 48, 48);
    var cr = new Cairo.Context (cst);

    cr.save ();

    var gradient = new Cairo.Pattern.linear (1,  1, 1, 1+48);
    gradient.add_color_stop_rgb (0, 0.7098, 0.7098, 0.7098);
    gradient.add_color_stop_rgb (1, 0.8901, 0.8901, 0.8901);
    cr.set_source (gradient);
    cr.rectangle (1, 1, 46, 46);
    cr.fill ();

    cr.restore ();

    try {
      var icon_info = IconTheme.get_default ().lookup_icon ("avatar-default", 48, IconLookupFlags.GENERIC_FALLBACK);
      var image = icon_info.load_icon ();
      if (image != null) {
	Gdk.cairo_set_source_pixbuf (cr, image, 3, 3);
	cr.paint();
      }
    } catch {
    }


    cr.push_group ();

    cr.set_source_rgba (0, 0, 0, 0);
    cr.paint ();
    round_rect (cr, 0, 0, 48, 48, 5);
    cr.set_source_rgb (0.74117, 0.74117, 0.74117);
    cr.fill ();
    round_rect (cr, 1, 1, 46, 46, 5);
    cr.set_source_rgb (1, 1, 1);
    cr.fill ();
    round_rect (cr, 2, 2, 44, 44, 5);
    cr.set_source_rgb (0.341176, 0.341176, 0.341176);
    cr.fill ();
    cr.set_operator (Cairo.Operator.CLEAR);
    round_rect (cr, 3, 3, 42, 42, 5);
    cr.set_source_rgba (0, 0, 0, 0);
    cr.fill ();

    var pattern = cr.pop_group ();
    cr.set_source (pattern);
    cr.paint ();

    return Gdk.pixbuf_get_from_surface (cst, 0, 0, 48, 48);
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

  // TODO: This should be async, but the vala bindings are broken (bug #649875)
  private Gdk.Pixbuf load_icon (File ?file) {
    Gdk.Pixbuf? res = fallback_avatar;
    if (file != null) {
      try {
	var stream = file.read ();
	Cancellable c = new Cancellable ();
	res = new Gdk.Pixbuf.from_stream_at_scale (stream, 48, 48, true, c);
      } catch (Error e) {
      }
    }
    return res;
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
	Individual individual;

	model.get (iter, 0, out individual);

	IndividualData data = individual.get_data("contacts-data");
	if (data.avatar == null)
	  data.avatar = load_icon (individual.avatar);
	cell.set ("pixbuf", data.avatar);
      });

    var text = new CellRendererText ();
    column.pack_start (text, true);
    text.set ("weight", Pango.Weight.BOLD);
    column.set_cell_data_func (text, (column, cell, model, iter) => {
	Individual individual;

	model.get (iter, 0, out individual);

	string? alias = individual.alias;
	cell.set ("text", alias);
      });

    icon = new CellRendererPixbuf ();
    column.pack_start (icon, false);
    column.set_cell_data_func (icon, (column, cell, model, iter) => {
	Individual individual;

	model.get (iter, 0, out individual);

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

  public App() {
    fallback_avatar = draw_fallback_avatar ();

    contacts_store = new ListStore(1, typeof (Folks.Individual));

    aggregator = new IndividualAggregator ();
    aggregator.individuals_changed.connect ((added, removed, m, a, r) =>   {
	foreach (Individual i in removed) {
	  IndividualData? data = i.get_data("contacts-data");
	  if (data != null) {
	    contacts_store.remove (data.iter);
	  } else {
	    stdout.printf("removed %p with no data!\n", i);
	  }
	}
	foreach (Individual i in added) {
	  var data = new IndividualData();
	  i.set_data ("contacts-data", data);

	  contacts_store.append (out data.iter);
	  contacts_store.set (data.iter, 0, i);

	  /* TODO: Connect to notify(?) for changes */
	}
      });
    aggregator.prepare ();

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

    groups_button.set_icon_name ("system-users-symbolic");
    groups_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    groups_button.is_important = false;
    toolbar.add (groups_button);

    groups_button.get_style_context ().set_junction_sides (JunctionSides.LEFT);

    var favourite_button = new ToggleToolButton ();
    favourite_button.set_icon_name ("user-bookmarks-symbolic");
    favourite_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    favourite_button.is_important = false;
    toolbar.add (favourite_button);
    favourite_button.get_style_context ().set_junction_sides (JunctionSides.RIGHT);

    var separator = new SeparatorToolItem ();
    separator.set_draw (false);
    toolbar.add (separator);

    var entry = new Entry ();
    entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");

    var search_entry_item = new ToolItem ();
    search_entry_item.is_important = false;
    search_entry_item.set_expand (true);
    search_entry_item.add (entry);
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

    tree_view = new TreeView.with_model (contacts_store);
    setup_contacts_view (tree_view);
    scrolled.add(tree_view);

    grid.show_all ();
  }
}
