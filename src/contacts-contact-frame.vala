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

public class Contacts.ContactFrame : Frame {
  private int size;
  private string? text;
  private Gdk.Pixbuf? pixbuf;
  private Pango.Layout? layout;
  private int text_height;
  private bool popup_in_progress;
  private Gtk.Menu? menu;

  private void menu_position (Gtk.Menu menu, out int x, out int y, out bool push_in) {
    Allocation allocation;
    get_allocation (out allocation);

    int sx = 0;
    int sy = 0;

    if (!get_has_window ()) {
      sx += allocation.x;
      sy += allocation.y;
    }

    get_window ().get_root_coords (sx, sy, out sx, out sy);

    Requisition menu_req;
    Gdk.Rectangle monitor;

    menu.get_preferred_size (null, out menu_req);

    if (get_direction () == TextDirection.LTR)
      x = sx + 2;
    else
      x = sx + allocation.width - menu_req.width - 2;
    y = sy - 2;

    var window = get_window ();
    var screen = get_screen ();
    var monitor_num = screen.get_monitor_at_window (window);
    if (monitor_num < 0)
      monitor_num = 0;
    screen.get_monitor_geometry (monitor_num, out monitor);

    if (x < monitor.x)
      x = monitor.x;
    else if (x + menu_req.width > monitor.x + monitor.width)
      x = monitor.x + monitor.width - menu_req.width;

    if (monitor.y + monitor.height - y - allocation.height >= menu_req.height)
      y += allocation.height;
    else if (y - monitor.y >= menu_req.height)
      y -= menu_req.height;
    else if (monitor.y + monitor.height - y - allocation.height > y - monitor.y)
      y += allocation.height;
    else
      y -= menu_req.height;

    menu.set_monitor (monitor_num);

    Window? toplevel = menu.get_parent() as Window;
    if (toplevel != null && !toplevel.get_visible())
      toplevel.set_type_hint (Gdk.WindowTypeHint.DROPDOWN_MENU);

    push_in = false;
  }

  public ContactFrame (int size, Gtk.Menu? menu = null) {
    this.size = size;

    var image = new Image ();
    image.set_size_request (size, size);

    this.menu = menu;

    var button = new ToggleButton ();
    button.set_focus_on_click (false);
    button.get_style_context ().add_class ("contact-frame-button");
    button.add (image);
    button.set_mode (false);
    this.add (button);

    button.toggled.connect ( () => {
	if (this.menu == null) {
	  if (button.get_active ())
	    button.set_active (false);
	  return;
	}

	if (button.get_active ()) {
	  if (!popup_in_progress) {
	    menu.popup (null, null, menu_position, 1, Gtk.get_current_event_time ());
	  }
	} else {
	  menu.popdown ();
	}
      });

    button.button_press_event.connect ( (event) => {
	if (this.menu == null)
	  return true;
	var ewidget = Gtk.get_event_widget ((Gdk.Event)(&event));

	if (ewidget != button ||
	    button.get_active ())
	  return false;

	menu.popup (null, null, menu_position, 1, Gtk.get_current_event_time ());
	button.set_active (true);
	popup_in_progress = true;
	return true;
      });

    button.button_release_event.connect ( (event) => {
	if (this.menu == null)
	  return false;

	bool popup_in_progress_saved = popup_in_progress;
	popup_in_progress = false;

	var ewidget = Gtk.get_event_widget ((Gdk.Event)(&event));

	if (ewidget == button &&
	    !popup_in_progress_saved &&
	    button.get_active ()) {
	  menu.popdown ();
	  return true;
	}
	if (ewidget != button)    {
	  menu.popdown ();
	  return true;
	}
	return false;
      });

    if (menu != null) {
      menu.show.connect ( (menu) => {
	  popup_in_progress = true;
	  button.set_active (true);
	  popup_in_progress = false;
	});
      menu.hide.connect ( (menu) => {
	  button.set_active (false);
	});
      menu.attach_to_widget (button, (menu) => {
	});
    }

    image.show ();
    image.draw.connect (draw_image);

    set_shadow_type (ShadowType.NONE);
  }

  public void set_image (AvatarDetails? details, Contact? contact = null) {
    pixbuf = null;
    if (details != null &&
	details.avatar != null) {
      try {
	var stream = details.avatar.load (size, null);
	pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, size, size, true);
      }
      catch {
      }
    }

    if (pixbuf == null) {
      pixbuf = Contact.draw_fallback_avatar (size, contact);
    }
    pixbuf = Contact.frame_icon (pixbuf);
    queue_draw ();
  }

  public void set_text (string? text_, int text_height_) {
    text = text_;
    text_height = text_height_;
    layout = null;
    if (text != null) {
      layout = create_pango_layout (text);
      Pango.Rectangle rect = {0 };
      int font_size = text_height - /* Y PADDING */ 4 +  /* Removed below */ 1;

      do {
	font_size = font_size - 1;
	var fd = new Pango.FontDescription();
	fd.set_absolute_size (font_size*Pango.SCALE);
	layout.set_font_description (fd);
	layout.get_extents (null, out rect);
      } while (rect.width > size * Pango.SCALE);
    }
    queue_draw ();
  }

  public bool draw_image (Cairo.Context cr) {
    cr.save ();

    if (pixbuf != null) {
      Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
      cr.paint();
    }

    if (layout != null) {
      Utils.cairo_rounded_box (cr, 0, 0, size, size, 4);
      cr.clip ();

      cr.set_source_rgba (0, 0, 0, 0.5);
      cr.rectangle (0, size - text_height, size, text_height);
      cr.fill ();

      cr.set_source_rgb (1.0, 1.0, 1.0);
      Pango.Rectangle rect;
      layout.get_extents (null, out rect);
      double label_width = rect.width/(double)Pango.SCALE;
      double label_height = rect.height / (double)Pango.SCALE;
      cr.move_to (Math.round ((size - label_width) / 2.0),
		  size - text_height + Math.floor ((text_height - label_height) / 2.0));
      Pango.cairo_show_layout (cr, layout);
    }
    cr.restore ();

    return true;
  }
}
