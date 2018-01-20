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

/**
 * The Avatar of a Contact is responsible for showing an {@link Individual}'s
 * avatar, or a fallback if it's not available.
 */
public class Contacts.Avatar : DrawingArea {
  private int size;
  private Gdk.Pixbuf? pixbuf;
  private Contact? contact;

  // The background color used in case of a fallback avatar
  private Gdk.RGBA? bg_color = null;
  // The color used for an initial or the fallback icon
  private const Gdk.RGBA fg_color = { 0, 0, 0, 0.25 };

  public Avatar (int size) {
    this.size = size;
    set_size_request (size, size);

    get_style_context ().add_class ("contacts-avatar");

    show ();
  }

  public void set_pixbuf (Gdk.Pixbuf? a_pixbuf) {
    this.pixbuf = a_pixbuf;
    queue_draw ();
  }

  public void set_image (AvatarDetails? details, Contact? contact = null) {
    this.contact = contact;

    // FIXME listen for changes in the Individual's avatar

    Gdk.Pixbuf? a_pixbuf = null;
    if (details != null && details.avatar != null) {
      try {
        var stream = details.avatar.load (size, null);
        a_pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, size, size, true);
      } catch {
      }
    }

    set_pixbuf (a_pixbuf);
  }

  public override bool draw (Cairo.Context cr) {
    cr.save ();

    if (this.pixbuf != null)
      draw_contact_avatar (cr);
    else // No avatar available, draw a fallback
      draw_fallback (cr);

    cr.restore ();

    return true;
  }

  private void draw_contact_avatar (Cairo.Context cr) {
    Gdk.cairo_set_source_pixbuf (cr, this.pixbuf, 0, 0);
    // Clip with a circle
    create_circle (cr);
    cr.clip_preserve ();
    cr.paint ();
  }

  private void draw_fallback (Cairo.Context cr) {
    // The background color
    if (this.bg_color == null)
      calculate_color ();

    // Fill the background circle
    cr.set_source_rgb (this.bg_color.red, this.bg_color.green, this.bg_color.blue);
    cr.arc (this.size / 2, this.size / 2, this.size / 2, 0, 2*Math.PI);
    create_circle (cr);
    cr.fill_preserve ();

    // Draw the icon
    try {
      // FIXME we can probably cache this
      var theme = IconTheme.get_default ();
      var fallback_avatar = theme.lookup_icon ("avatar-default",
                                               this.size * 4 / 5,
                                               IconLookupFlags.FORCE_SYMBOLIC);
      var icon_pixbuf = fallback_avatar.load_symbolic (fg_color);
      create_circle (cr);
      cr.clip_preserve ();
      Gdk.cairo_set_source_pixbuf (cr, icon_pixbuf, 1 + this.size / 10, 1 + this.size / 5);
      cr.paint ();
    } catch (Error e) {
      warning ("Couldn't get default avatar icon: %s", e.message);
    }
  }

  private void calculate_color () {
    // We use the hash of the id so we get the same color each time for the same contact
    var hash = (this.contact != null)? str_hash (this.contact.individual.id) : Gdk.CURRENT_TIME;

    var r = ((hash & 0xFF0000) >> 16) / 255.0;
    var g = ((hash & 0x00FF00) >> 8) / 255.0;
    var b = (hash & 0x0000FF) / 255.0;

    // Make it a bit lighter by default (and since the foreground will be darker)
    this.bg_color = Gdk.RGBA () {
      red = (r + 2) / 3.0,
      green = (g + 2) / 3.0,
      blue = (b + 2) / 3.0,
      alpha = 0
    };
  }

  private void create_circle (Cairo.Context cr) {
    cr.arc (this.size / 2, this.size / 2, this.size / 2, 0, 2*Math.PI);
  }
}
