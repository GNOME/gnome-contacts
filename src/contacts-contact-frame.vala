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

  public signal void clicked ();

  public ContactFrame (int size, bool with_button = false) {
    this.size = size;

    var image = new Image ();
    image.set_size_request (size, size);

    if (with_button) {
      var button = new Button ();
      button.get_style_context ().add_class ("contacts-square");
      button.set_relief (ReliefStyle.NONE);
      button.set_focus_on_click (false);
      button.add (image);

      button.clicked.connect ( () => {
	  this.clicked ();
	});

      this.add (button);
    } else {
      this.add (image);
    }

    image.show ();
    image.draw.connect (draw_image);

    set_shadow_type (ShadowType.NONE);
  }

  public void set_pixbuf (Gdk.Pixbuf a_pixbuf) {
    pixbuf = Contact.frame_icon (a_pixbuf);
    queue_draw ();
  }

  public void set_image (AvatarDetails? details, Contact? contact = null) {
    Gdk.Pixbuf? a_pixbuf = null;
    if (details != null &&
	details.avatar != null) {
      try {
	var stream = details.avatar.load (size, null);
	a_pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, size, size, true);
      }
      catch {
      }
    }

    if (a_pixbuf == null) {
      a_pixbuf = Contact.draw_fallback_avatar (size, contact);
    }
    set_pixbuf (a_pixbuf);
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
