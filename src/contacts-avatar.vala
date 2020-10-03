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
public class Contacts.Avatar : Bin {
  private Hdy.Avatar widget;

  private Individual? individual = null;

  public Avatar (int size, Individual? individual = null) {
    this.individual = individual;
    string name = "";
    bool show_initials = false;
    if (this.individual != null) {
      name = find_display_name ();
      /* If we don't have a usable name use the display_name
       * to generate the color but don't show any label
       */
      if (name == "") {
        name = this.individual.display_name;
      } else {
        show_initials = true;
      }
    }

    this.widget = new Hdy.Avatar (size, name, show_initials);
    this.widget.set_image_load_func (size => load_avatar (size));
    this.widget.show ();
    add(this.widget);

    show ();
  }

  /**
   * Manually set the avatar to the given pixbuf, even if the contact has an avatar.
   */
  public void set_pixbuf (Gdk.Pixbuf? a_pixbuf) {
    this.widget.set_image_load_func (size => load_avatar (size, a_pixbuf));
  }

  private Gdk.Pixbuf? load_avatar (int size, Gdk.Pixbuf? pixbuf = null) {
    if (pixbuf != null) {
      return pixbuf.scale_simple (size, size, Gdk.InterpType.HYPER);
    } else {
      if (this.individual != null && this.individual.avatar != null) {
        try {
          var stream = this.individual.avatar.load (size, null);
          return new Gdk.Pixbuf.from_stream_at_scale (stream, size, size, true);
        } catch (Error e) {
          debug ("Couldn't load avatar of contact %s. Reason: %s", this.individual.display_name, e.message);
        }
      }
    }
    return null;
  }

  /* Find a nice name to generate the label and color for the fallback avatar
   * This code is mostly copied from folks, but folks also tries email and phone number
   * as a display name which we don't want to have as a label
   */
  private string find_display_name () {
    string name = "";
    Persona primary_persona = null;
    foreach (var p in this.individual.personas) {
      if (p.store.is_primary_store) {
        primary_persona = p;
        break;
      }
    }
    name = look_up_alias_for_display_name (primary_persona);
    if (name == "") {
      foreach (var p in this.individual.personas) {
        name = look_up_alias_for_display_name (p);
      }
    }
    if (name == "") {
      foreach (var p in this.individual.personas) {
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
