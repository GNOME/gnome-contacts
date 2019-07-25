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
 * The Avatar of a Contact is responsible for showing an {@link Folks.Individual}'s
 * avatar, or a fallback if it's not available.
 */
public class Contacts.Avatar : DrawingArea {
  private int size;
  private Gdk.Pixbuf? pixbuf = null;
  private Gdk.Pixbuf? cache = null;

  private Contact? contact = null;
  // We want to lazily load the Pixbuf to make sure we don't draw all contact avatars at once.
  // As long as there is no need for it to be drawn, keep this to false.
  private bool avatar_loaded = false;

  public Avatar (int size, Contact? contact = null) {
    this.contact = contact;
    if (contact != null) {
      contact.individual.notify["avatar"].connect ( (s, p) => {
          load_avatar.begin ();
        });
    }

    this.size = size;
    set_size_request (size, size);

    // If we don't have an avatar, don't try to load it later
    this.avatar_loaded = (contact == null || contact.individual.avatar == null);

    show ();
  }

  /**
   * Manually set the avatar to the given pixbuf, even if the contact has an avatar.
   */
  public void set_pixbuf (Gdk.Pixbuf? a_pixbuf) {
    this.cache = null;
    this.pixbuf = a_pixbuf;
    queue_draw ();
  }

  private async void load_avatar () {
    assert (this.contact != null);

    this.avatar_loaded = true;
    try {
      var stream = yield this.contact.individual.avatar.load_async (this.size);
      this.cache = null;
      this.pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async (stream, this.size, this.size, true);
      queue_draw ();
    } catch (Error e) {
      debug ("Couldn't load avatar of contact %s. Reason: %s", this.contact.individual.display_name, e.message);
    }
  }

  public override bool draw (Cairo.Context cr) {
    // This exists to implement lazy loading: i.e. only load the avatar on the first draw()
    if (!this.avatar_loaded)
      load_avatar.begin ();

    if (this.cache != null) {
    // Don't do anything if we have already a cached avatar
    } else if (this.pixbuf != null)
      this.cache = create_contact_avatar ();
    else // No avatar or cache available, create the fallback
      this.cache = create_fallback ();

    draw_cached_avatar (cr);

    return true;
  }

  private void draw_cached_avatar (Cairo.Context cr) {
    Gdk.cairo_set_source_pixbuf (cr, this.cache, 0, 0);
    cr.paint ();
  }

  private Gdk.Pixbuf create_contact_avatar () {
    return AvatarUtils.round_image(this.pixbuf);
  }

  private Gdk.Pixbuf create_fallback () {
    string name = "";
    bool show_label = false;
    if (this.contact != null && this.contact.individual != null) {
      name = find_display_name ();
      /* If we don't have a usable name use the display_name
       * to generate the color but don't show any label
       */
      if (name == "") {
        name = this.contact.individual.display_name;
      } else {
        show_label = true;
      }
    }
    var pixbuf = AvatarUtils.generate_user_picture(name, this.size, show_label);
    pixbuf = AvatarUtils.round_image(pixbuf);

    return pixbuf;
  }

  /* Find a nice name to generate the label and color for the fallback avatar
   * This code is mostly copied from folks, but folks also tries email and phone number
   * as a display name which we don't want to have as a label
   */
  private string find_display_name () {
    string name = "";
    Persona primary_persona = null;
    foreach (var p in this.contact.individual.personas) {
      if (p.store.is_primary_store) {
        primary_persona = p;
        break;
      }
    }
    name = look_up_alias_for_display_name (primary_persona);
    if (name == "") {
      foreach (var p in this.contact.individual.personas) {
        name = look_up_alias_for_display_name (p);
      }
    }
    if (name == "") {
      foreach (var p in this.contact.individual.personas) {
        name = look_up_name_details_for_display_name (p);
      }
    }
    return name;
  }

  private string look_up_alias_for_display_name (Persona? p) {
    var a = p as AliasDetails;
    if (a != null && a.alias != null)
      return a.alias;

    return "";
  }

  private string look_up_name_details_for_display_name (Persona? p) {
    var n = p as NameDetails;
    if (n != null) {
      if (n.full_name != null && n.full_name != "")
        return n.full_name;
      else if (n.structured_name != null)
        return n.structured_name.to_string ();
      else if (n.nickname != "")
        return n.nickname;
    }

    return "";
  }
}
