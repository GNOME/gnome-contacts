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

using Folks;

/**
 * The Avatar of a Contact is responsible for showing an {@link Folks.Individual}'s
 * avatar, or a fallback if it's not available.
 */
public class Contacts.Avatar : Adw.Bin {

  private unowned Individual? _individual = null;
  public Individual? individual {
    get { return this._individual; }
    set {
      if (this._individual == value)
        return;

      this._individual = value;
      update_individual ();
    }
  }

  private int avatar_size;

  public Avatar (int size, Individual? individual = null) {
    this.child = new Adw.Avatar (size, "", false);
    this.avatar_size = size;

    this.individual = individual;
  }

  private void update_individual () {
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

    ((Adw.Avatar) this.child).show_initials = show_initials;
    ((Adw.Avatar) this.child).text = name;

    this.load_avatar.begin ();
  }

  public async void load_avatar () {
    if (this.individual == null || this.individual.avatar == null) {
      set_pixbuf (null);
      return;
    }

    try {
      var stream = yield this.individual.avatar.load_async (this.avatar_size,
                                                            null);
      var pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async (stream,
                                                                    this.avatar_size,
                                                                    this.avatar_size,
                                                                    true);
      this.set_pixbuf (pixbuf);
    } catch (Error e) {
      warning ("Couldn't load avatar of '%s': %s", this.individual.display_name, e.message);
    }
  }

  /**
   * Manually set the avatar to the given pixbuf, even if the contact has an avatar.
   */
  public void set_pixbuf (Gdk.Pixbuf? a_pixbuf) {
    var img = (a_pixbuf != null)? Gdk.Texture.for_pixbuf (a_pixbuf) : null;
    ((Adw.Avatar) this.child).set_custom_image (img);
  }

  /* Find a nice name to generate the label and color for the fallback avatar
   * This code is mostly copied from folks, but folks also tries email and phone number
   * as a display name which we don't want to have as a label
   */
  private string find_display_name () {
    unowned Persona primary_persona = null;
    foreach (var p in this.individual.personas) {
      if (p.store.is_primary_store) {
        primary_persona = p;
        break;
      }
    }

    unowned string alias = look_up_alias_for_display_name (primary_persona);
    if (alias != "")
      return alias;

    foreach (var p in this.individual.personas) {
      alias = look_up_alias_for_display_name (p);
      if (alias != "")
        return alias;
    }

    foreach (var p in this.individual.personas) {
      string name = look_up_name_details_for_display_name (p);
      if (name != "")
        return name;
    }
    return "";
  }

  private unowned string look_up_alias_for_display_name (Persona? p) {
    unowned var a = p as AliasDetails;
    if (a != null && a.alias != null)
      return a.alias;

    return "";
  }

  private string look_up_name_details_for_display_name (Persona? p) {
    unowned var n = p as NameDetails;
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
