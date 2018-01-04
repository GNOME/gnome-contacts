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
  private Gdk.Pixbuf? pixbuf;
  private Contact? contact;

  public signal void clicked ();

  public ContactFrame (int size, bool with_button = false) {
    this.size = size;
    this.contact = null;

    var image = new DrawingArea ();
    image.set_size_request (size, size);
    //TODO Border (or not? what if we have a color)

    if (with_button) {
      var button = new Button ();
      button.get_accessible ().set_name (_("Change avatar"));
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
    image.draw.connect (on_draw_avatar);

    set_shadow_type (ShadowType.NONE);
  }

  public void set_pixbuf (Gdk.Pixbuf? a_pixbuf) {
    this.pixbuf = (a_pixbuf != null)? Contact.frame_icon (a_pixbuf) : null;
    queue_draw ();
  }

  public void set_image (AvatarDetails? details, Contact? contact = null) {
    this.contact = contact;

    Gdk.Pixbuf? a_pixbuf = null;
    if (details != null && details.avatar != null) {
      try {
        var stream = details.avatar.load (size, null);
        a_pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, size, size, true);
      }
      catch {
      }
    }

    if (a_pixbuf == null) {
      a_pixbuf = null;
    }
    set_pixbuf (a_pixbuf);
  }

  public bool on_draw_avatar (Cairo.Context cr) {
    cr.save ();

    if (this.pixbuf != null)
      draw_pixbuf (cr);
    else // Draw the standard person fallback
      draw_initial (cr);

    cr.restore ();

    return true;
  }

  private void draw_pixbuf (Cairo.Context cr) {
    Gdk.cairo_set_source_pixbuf (cr, this.pixbuf, 0, 0);
    // Clip with a circle
    cr.arc (this.size / 2, this.size / 2, (this.size - 1) / 2, 0, 2*Math.PI);
    cr.clip_preserve ();
    cr.paint ();

    // Draw a border
    cr.arc (this.size / 2, this.size / 2, (this.size - 1) / 2, 0, 2*Math.PI);
    cr.set_line_width (0.5);
    cr.set_source_rgb (0, 0, 0);
    cr.stroke ();
  }

  private void draw_initial (Cairo.Context cr) {
    // The background colors
    double bg_r, bg_g, bg_b;
    get_background_color (out bg_r, out bg_g, out bg_b);
    // The foreground colors
    var fg_r = bg_r * 0.5;
    var fg_g = bg_g * 0.5;
    var fg_b = bg_b * 0.5;

    // Draw the background circle
    cr.set_source_rgb (bg_r, bg_g, bg_b);
    cr.arc (this.size / 2, this.size / 2, (this.size - 1) / 2, 0, 2*Math.PI);
    cr.fill_preserve ();
    // Draw the border
    cr.set_line_width (0.5);
    cr.set_source_rgb (fg_r, fg_g, fg_b);
    cr.stroke ();

    // Draw the initial
    if (this.contact != null && this.contact.display_name != "") {
      var initial = this.contact.display_name.get_char_validated ();
      if (initial == -1)
        return;
      var initial_upper = initial.totitle ().to_string ();

      // Get the styling right
      cr.set_source_rgb (fg_r, fg_g, fg_b);
      //XXX no better way to do this (ie without hardcoding Cantarell)
      cr.select_font_face ("Cantarell", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
      cr.set_font_size (this.size * 0.66);
      // Center it
      Cairo.TextExtents extents;
      cr.text_extents (initial_upper, out extents);
      cr.move_to ((this.size - extents.width) / 2 - extents.x_bearing,
                  (this.size - extents.height) / 2 - extents.y_bearing);

      cr.show_text (initial_upper);
    }
  }

  private void get_background_color (out double r, out double g, out double b) {
    //XXX find something if this.contact == nulll or id == ""

    // We use the hash of the id so we get the same color for a contact
    var hash = str_hash (this.contact.individual.id);

    r = ((hash & 0xFF0000) >> 16) / 255.0;
    g = ((hash & 0x00FF00) >> 8) / 255.0;
    b = (hash & 0x0000FF) / 255.0;

    // Make it a bit lighter by default (and since the foreground will be darker)
    r = (r + 2) / 3.0;
    g = (g + 2) / 3.0;
    b = (b + 2) / 3.0;
  }
}
