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

public class Contacts.CellRendererShape : Gtk.CellRenderer {
  public const int IMAGE_SIZE = 14;

  private Widget current_widget;

  public string name { get;  set; }
  public PresenceType presence { get;  set; }
  public string message { get;  set; }
  public bool is_phone  { get;  set; }
  public int wrap_width { get;  set; default=-1;}

  Gdk.Pixbuf? create_symbolic_pixbuf (Widget widget, string icon_name, int size) {
    var screen = widget. get_screen ();
    var icon_theme = Gtk.IconTheme.get_for_screen (screen);

    var info = icon_theme.lookup_icon (icon_name, size, Gtk.IconLookupFlags.USE_BUILTIN);
    if (info == null)
      return null;

    var context = widget.get_style_context ();

    context.save ();
    bool is_symbolic;
    context.add_class (Contact.presence_to_class (presence));
    var pixbuf = info.load_symbolic_for_context (context,
						 out is_symbolic);
    context.restore ();

    if (!is_symbolic)
      pixbuf = null;

    return pixbuf;
  }


  private Pango.Layout get_layout (Widget           widget,
				   Gdk.Rectangle? cell_area,
				   CellRendererState flags) {
    Pango.Layout layout;
    int xpad;

    string str = name;
    var attr_list = new Pango.AttrList();
    var a = Pango.attr_weight_new (Pango.Weight.BOLD);
    a.start_index = 0;
    a.end_index = a.start_index + str.length;
    attr_list.insert ((owned) a);

    string? iconname = Contact.presence_to_icon (presence);
    if (iconname != null) {
      // This is 'LINE SEPARATOR' (U+2028) which gives us a new line but not a new paragraph
      str += "\xE2\x80\xA8*";
      Pango.Rectangle r = { 0, -CellRendererShape.IMAGE_SIZE*1024*9/10,
			    CellRendererShape.IMAGE_SIZE*1024, CellRendererShape.IMAGE_SIZE*1024 };
      a = new Pango.AttrShape<string>.with_data (r, r, iconname, string.dup);
      a.start_index = str.length - 1;
      a.end_index = a.start_index + 1;
      attr_list.insert ((owned) a);
      if (message != null) {
	string m = message;
	if (m.length == 0)
	  m = Contact.presence_to_string (presence);
	str += " " + m;
	if (is_phone) {
	  if ((flags & CellRendererState.SELECTED) != 0)
	    a = Pango.attr_foreground_new (0xffff-0x8e8e, 0xffff-0x9191, 0xffff-0x9292);
	  else
	    a = Pango.attr_foreground_new (0x8e8e, 0x9191, 0x9292);
	  a.start_index = str.length;
	  str += " (via phone)";
	  a.end_index = str.length;
	  attr_list.insert ((owned) a);
	}
      }
    }

    layout = widget.create_pango_layout (str);

    get_padding (out xpad, null);

    /* Now apply the attributes as they will effect the outcome
     * of pango_layout_get_extents() */
    layout.set_attributes (attr_list);

    layout.set_ellipsize (Pango.EllipsizeMode.END);

    if (wrap_width != -1) {
      Pango.Rectangle rect;
      int width, text_width;

      layout.get_extents (null, out rect);
      text_width = rect.width;

      if (cell_area != null)
	width = (cell_area.width - xpad * 2) * Pango.SCALE;
      else
	width = wrap_width * Pango.SCALE;

      width = int.min (width, text_width);

      layout.set_width (width);
    } else {
      layout.set_width (-1);
    }

    layout.set_wrap (Pango.WrapMode.CHAR);

    layout.set_height (-2);

    Pango.Alignment align;
    if (widget.get_direction () == TextDirection.RTL)
	align = Pango.Alignment.RIGHT;
      else
	align = Pango.Alignment.LEFT;
    layout.set_alignment (align);

    return layout;
  }

  public override void get_size (Widget        widget,
				 Gdk.Rectangle? cell_area,
				 out int       x_offset,
				 out int       y_offset,
				 out int       width,
				 out int       height) {
  }

  private void do_get_size (Widget        widget,
			    Gdk.Rectangle? cell_area,
			    Pango.Layout? _layout,
			    out int       x_offset,
			    out int       y_offset,
			    out int       width,
			    out int       height) {
    Pango.Rectangle rect;
    int xpad, ypad;

    get_padding (out xpad, out ypad);

    Pango.Layout layout;
    if (_layout == null)
      layout = get_layout (widget, null, 0);
    else
      layout = _layout;

    layout.get_pixel_extents (null, out rect);

    if (cell_area != null) {
      rect.height = int.min (rect.height, cell_area.height - 2 * ypad);
      rect.width  = int.min (rect.width, cell_area.width - 2 * xpad);

      if (widget.get_direction () == TextDirection.RTL)
	x_offset = cell_area.width - (rect.width + (2 * xpad));
      else
	x_offset = 0;

      x_offset = int.max (x_offset, 0);

      y_offset = 0;
    } else {
      x_offset = 0;
      y_offset = 0;
    }

    height = ypad * 2 + rect.height;
    width = xpad * 2 + rect.width;
  }

  public override void render (Cairo.Context   cr,
			       Widget          widget,
			       Gdk.Rectangle   background_area,
			       Gdk.Rectangle   cell_area,
			       CellRendererState flags) {
    StyleContext context;
    Pango.Layout layout;
    int x_offset = 0;
    int y_offset = 0;
    int xpad, ypad;
    Pango.Rectangle rect;

    current_widget = widget;

    layout = get_layout (widget, cell_area, flags);
    do_get_size (widget, cell_area, layout, out x_offset, out y_offset, null, null);
    context = widget.get_style_context ();

    get_padding (out xpad, out ypad);

    layout.set_width ((cell_area.width - x_offset - 2 * xpad) * Pango.SCALE);

    layout.get_pixel_extents (null, out rect);
    x_offset = x_offset - rect.x;

    cr.save ();

    Gdk.cairo_rectangle (cr, cell_area);
    cr.clip ();

    Gtk.render_layout (context, cr,
		       cell_area.x + x_offset + xpad,
		       cell_area.y + y_offset + ypad,
		       layout);

    cr.restore ();
  }

  public override void get_preferred_width (Widget       widget,
					    out int      min_width,
					    out int      nat_width) {
    Pango.Rectangle  rect;
    int text_width, xpad;

    get_padding (out xpad, null);

    var layout = get_layout (widget, null, 0);

    /* Fetch the length of the complete unwrapped text */
    layout.set_width (-1);
    layout.get_extents (null, out rect);
    text_width = rect.width;

    min_width = xpad * 2 + rect.x + int.min (text_width / Pango.SCALE, wrap_width);
    nat_width = xpad * 2 + text_width / Pango.SCALE;
    nat_width = int.max (nat_width, min_width);
  }

  public override void get_preferred_height_for_width (Widget       widget,
						       int          width,
						       out int      minimum_height,
						       out int      natural_height) {
    Pango.Layout  layout;
    int text_height, xpad, ypad;

    get_padding (out xpad, out ypad);

    layout = get_layout (widget, null, 0);
    layout.set_width ((width - xpad * 2) * Pango.SCALE);
    layout.get_pixel_size (null, out text_height);

    minimum_height = text_height + ypad * 2;
    natural_height = text_height + ypad * 2;
  }

  public override void get_preferred_height (Widget       widget,
					     out int      minimum_size,
					     out int      natural_size) {
    int min_width;

    get_preferred_width (widget, out min_width, null);
    get_preferred_height_for_width (widget, min_width,
				    out minimum_size, out natural_size);
  }

  public void render_shape (Cairo.Context cr, Pango.AttrShape attr, bool do_path) {
    unowned Pango.AttrShape<string> sattr = (Pango.AttrShape<string>)attr;
    var pixbuf = create_symbolic_pixbuf (current_widget, sattr.data, IMAGE_SIZE);
    if (pixbuf != null) {
      double x, y;
      cr.get_current_point (out x, out y);
      Gdk.cairo_set_source_pixbuf (cr, pixbuf, x, y-IMAGE_SIZE*0.9);
      cr.paint();
    }
  }
}

public class Contacts.ListPane : Frame {
  private Store contacts_store;
  private TreeView contacts_tree_view;
  public Entry filter_entry;
  private uint filter_entry_changed_id;
  private CellRendererShape shape;

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

    shape = new CellRendererShape ();

    Pango.cairo_context_set_shape_renderer (tree_view.get_pango_context (), shape.render_shape);

    column.pack_start (shape, false);
    column.set_cell_data_func (shape, (column, cell, model, iter) => {
	Contact contact;

	model.get (iter, 0, out contact);

	cell.set ("wrap_width", 230,
		  "name", contact.display_name,
		  "presence", contact.presence_type,
		  "message", contact.presence_message,
		  "is_phone", contact.is_phone);
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
    // We make the button slightly wider to look better since it
    // becomes taller when added to the toolbar
    add_button.set_size_request (34, -1);
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
