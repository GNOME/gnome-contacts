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

public class Contacts.CellRendererShape : Gtk.CellRenderer {
  public const int IMAGE_SIZE = 14;

  private Widget current_widget;

  public string name { get;  set; }
  public PresenceType presence { get;  set; }
  public string message { get;  set; }
  public bool is_phone  { get;  set; }
  public bool show_presence  { get;  set; }
  const int default_width = 60;
  int renderer_height = Contact.SMALL_AVATAR_SIZE;

  private struct IconShape {
    string icon;
  }

  Gdk.Pixbuf? create_symbolic_pixbuf (Widget widget, string icon_name, int size) {
    var screen = widget. get_screen ();
    var icon_theme = Gtk.IconTheme.get_for_screen (screen);

    var info = icon_theme.lookup_icon (icon_name, size, Gtk.IconLookupFlags.USE_BUILTIN);
    if (info == null)
      return null;

    var context = widget.get_style_context ();

    context.save ();
    bool is_symbolic;
    Gdk.Pixbuf? pixbuf = null;
    try {
      pixbuf = info.load_symbolic_for_context (context,
					       out is_symbolic);
    } catch (Error e) {
    }
    context.restore ();

    return pixbuf;
  }

  private Pango.Layout get_name_layout (Widget           widget,
					Gdk.Rectangle? cell_area,
					CellRendererState flags) {
    Pango.Layout layout;
    int xpad;

    var attr_list = new Pango.AttrList ();

    layout = widget.create_pango_layout (name);

    var attr = new Pango.AttrSize (13 * Pango.SCALE);
    attr.absolute = 1;
    attr.start_index = 0;
    attr.end_index = attr.start_index + name.length;
    attr_list.insert ((owned) attr);

    /* Now apply the attributes as they will effect the outcome
     * of pango_layout_get_extents() */
    layout.set_attributes (attr_list);

    // We only look at xpad, and only use it for the left side...
    get_padding (out xpad, null);

    layout.set_ellipsize (Pango.EllipsizeMode.END);

    Pango.Rectangle rect;
    int width, text_width;

    layout.get_extents (null, out rect);
    text_width = rect.width;

    if (cell_area != null)
      width = (cell_area.width - xpad) * Pango.SCALE;
    else
      width = default_width * Pango.SCALE;

    width = int.min (width, text_width);

    layout.set_width (width);

    layout.set_wrap (Pango.WrapMode.WORD_CHAR);
    layout.set_height (-2);

    Pango.Alignment align;
    if (widget.get_direction () == TextDirection.RTL)
	align = Pango.Alignment.RIGHT;
      else
	align = Pango.Alignment.LEFT;
    layout.set_alignment (align);

    return layout;
  }

  private Pango.Layout get_presence_layout (Widget           widget,
					    Gdk.Rectangle? cell_area,
					    CellRendererState flags) {
    Pango.Layout layout;
    int xpad;
    Pango.Rectangle r = { 0, -CellRendererShape.IMAGE_SIZE*1024*7/10,
			  CellRendererShape.IMAGE_SIZE*1024, CellRendererShape.IMAGE_SIZE*1024 };

    var attr_list = new Pango.AttrList ();

    string? str = "";
    string? iconname = Contact.presence_to_icon (presence);
    if (iconname != null && show_presence) {
      str += "*";
      IconShape icon_shape = IconShape();
      icon_shape.icon = iconname;
      var a = new Pango.AttrShape<IconShape?>.with_data (r, r, icon_shape, (s) => { return s;} );
      a.start_index = 0;
      a.end_index = 1;
      attr_list.insert ((owned) a);
      str += " ";
    }
    if (message != null && (!show_presence || iconname != null)) {
      string m = message;
      if (m.length == 0)
	m = Contact.presence_to_string (presence);

      var attr = new Pango.AttrSize (9 * Pango.SCALE);
      attr.absolute = 1;
      attr.start_index = str.length;
      attr.end_index = attr.start_index + m.length;
      attr_list.insert ((owned) attr);
      str += m;

      if (is_phone && show_presence) {
	var icon_shape = IconShape();
	icon_shape.icon = "phone-symbolic";
	var a = new Pango.AttrShape<IconShape?>.with_data (r, r, icon_shape, (s) => { return s;});
	a.start_index = str.length;
	str += "*";
	a.end_index = str.length;
	attr_list.insert ((owned) a);
      }
    }

    layout = widget.create_pango_layout (str);

    get_padding (out xpad, null);

    /* Now apply the attributes as they will effect the outcome
     * of pango_layout_get_extents() */
    layout.set_attributes (attr_list);

    layout.set_ellipsize (Pango.EllipsizeMode.END);

    Pango.Rectangle rect;
    int width, text_width;

    layout.get_extents (null, out rect);
    text_width = rect.width;

    if (cell_area != null)
      width = (cell_area.width - xpad) * Pango.SCALE;
    else
      width = default_width * Pango.SCALE;

    width = int.min (width, text_width);

    layout.set_width (width);

    layout.set_wrap (Pango.WrapMode.WORD_CHAR);

    layout.set_height (-1);

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
    x_offset = y_offset = width = height = 0;
    // Not used
  }

  private void do_get_size (Widget        widget,
			    Gdk.Rectangle? cell_area,
			    Pango.Layout? layout,
			    out int       x_offset,
			    out int       y_offset) {
    Pango.Rectangle rect;
    int xpad, ypad;

    get_padding (out xpad, out ypad);

    layout.get_pixel_extents (null, out rect);

    if (cell_area != null) {
      rect.width  = int.min (rect.width, cell_area.width - 2 * xpad);

      if (widget.get_direction () == TextDirection.RTL)
	x_offset = cell_area.width - (rect.width + xpad);
      else
	x_offset = xpad;

      x_offset = int.max (x_offset, 0);
    } else {
      x_offset = 0;
    }

    y_offset = ypad;
  }

  public override void render (Cairo.Context   cr,
			       Widget          widget,
			       Gdk.Rectangle   background_area,
			       Gdk.Rectangle   cell_area,
			       CellRendererState flags) {
    StyleContext context;
    Pango.Layout name_layout, presence_layout;
    int name_x_offset = 0;
    int presence_x_offset = 0;
    int name_y_offset = 0;
    int presence_y_offset = 0;
    int xpad;
    Pango.Rectangle name_rect;
    Pango.Rectangle presence_rect;

    current_widget = widget;

    context = widget.get_style_context ();
    get_padding (out xpad, null);

    name_layout = get_name_layout (widget, cell_area, flags);
    do_get_size (widget, cell_area, name_layout, out name_x_offset, out name_y_offset);
    name_layout.get_pixel_extents (null, out name_rect);
    name_x_offset = name_x_offset - name_rect.x;

    presence_layout = null;
    if (name_layout.get_lines_readonly ().length () == 1) {
      presence_layout = get_presence_layout (widget, cell_area, flags);
      do_get_size (widget, cell_area, presence_layout, out presence_x_offset, out presence_y_offset);
      presence_layout.get_pixel_extents (null, out presence_rect);
      presence_x_offset = presence_x_offset - presence_rect.x;
    }

    cr.save ();

    Gdk.cairo_rectangle (cr, cell_area);
    cr.clip ();

    context.render_layout (cr,
			   cell_area.x + name_x_offset,
			   cell_area.y + name_y_offset,
			   name_layout);

    if (presence_layout != null)
      context.render_layout (cr,
			     cell_area.x + presence_x_offset,
			     cell_area.y + presence_y_offset + renderer_height - 11 - presence_layout.get_baseline () / Pango.SCALE,
			     presence_layout);

    cr.restore ();
  }

  public override void get_preferred_width (Widget       widget,
					    out int      min_width,
					    out int      nat_width) {
    int xpad;

    get_padding (out xpad, null);

    nat_width = min_width = xpad + default_width;
  }

  public override void get_preferred_height_for_width (Widget       widget,
						       int          width,
						       out int      minimum_height,
						       out int      natural_height) {
    int ypad;

    get_padding (null, out ypad);
    minimum_height = renderer_height + ypad;
    natural_height = renderer_height + ypad;
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
    var pixbuf = create_symbolic_pixbuf (current_widget, sattr.data.icon, IMAGE_SIZE);
    if (pixbuf != null) {
      double x, y;
      cr.get_current_point (out x, out y);
      Gdk.cairo_set_source_pixbuf (cr, pixbuf, x, y-IMAGE_SIZE*0.7);
      cr.paint();
    }
  }
}
