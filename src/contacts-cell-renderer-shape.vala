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

  private struct IconShape {
    string icon;
    bool colorize;
  }

  Gdk.Pixbuf? create_symbolic_pixbuf (Widget widget, string icon_name, bool colorize, int size) {
    var screen = widget. get_screen ();
    var icon_theme = Gtk.IconTheme.get_for_screen (screen);

    var info = icon_theme.lookup_icon (icon_name, size, Gtk.IconLookupFlags.USE_BUILTIN);
    if (info == null)
      return null;

    var context = widget.get_style_context ();

    context.save ();
    bool is_symbolic;
    if (colorize)
      context.add_class (Contact.presence_to_class (presence));
    Gdk.Pixbuf? pixbuf = null;
    try {
      pixbuf = info.load_symbolic_for_context (context,
					       out is_symbolic);
    } catch (Error e) {
    }
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
      IconShape icon_shape = IconShape();
      icon_shape.icon = iconname;
      icon_shape.colorize = true;
      a = new Pango.AttrShape<IconShape?>.with_data (r, r, icon_shape, (s) => { return s;} );
      a.start_index = str.length - 1;
      a.end_index = a.start_index + 1;
      attr_list.insert ((owned) a);
      if (message != null) {
	string m = message;
	if (m.length == 0)
	  m = Contact.presence_to_string (presence);
	str += " " + m;
	if (is_phone) {
	  icon_shape = IconShape();
	  icon_shape.icon = "phone-symbolic";
	  a = new Pango.AttrShape<IconShape?>.with_data (r, r, icon_shape, (s) => { return s;});
	  a.start_index = str.length;
	  str += "*";
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
    unowned Pango.AttrShape<IconShape?> sattr = (Pango.AttrShape<IconShape?>)attr;
    var pixbuf = create_symbolic_pixbuf (current_widget, sattr.data.icon, sattr.data.colorize, IMAGE_SIZE);
    if (pixbuf != null) {
      double x, y;
      cr.get_current_point (out x, out y);
      Gdk.cairo_set_source_pixbuf (cr, pixbuf, x, y-IMAGE_SIZE*0.9);
      cr.paint();
    }
  }
}

