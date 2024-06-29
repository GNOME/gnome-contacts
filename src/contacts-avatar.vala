/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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

  private unowned Contact? _contact = null;
  public Contact? contact {
    get { return this._contact; }
    set {
      if (this._contact == value)
        return;

      this._contact = value;
      update_contact ();
    }
  }

  public int avatar_size { get; set; default = 48; }

  construct {
    this.child = new Adw.Avatar (this.avatar_size, "", false);
    bind_property ("avatar-size", this.child, "size", BindingFlags.DEFAULT);
  }

  public Avatar (int size, Individual? individual = null) {
    Object (avatar_size: size, individual: individual);
  }

  public Avatar.for_contact (int size, Contact contact) {
    Object (avatar_size: size, contact: contact);
  }

  private void update_individual () {
    if (this.contact != null)
      return;

    string name = "";
    bool show_initials = false;
    if (this.individual != null) {
      name = find_display_name ();
      // If we don't have a usable name use the display_name
      // to generate the color but don't show any label
      if (name == "") {
        name = this.individual.display_name;
      } else {
        show_initials = true;
      }
    }

    ((Adw.Avatar) this.child).show_initials = show_initials;
    ((Adw.Avatar) this.child).text = name;

    var icon = (this.individual != null)? this.individual.avatar : null;
    this.load_avatar.begin (icon);
  }

  private void update_contact () {
    if (this.individual != null)
      return;

    string name = "";
    bool show_initials = false;
    if (this.contact != null) {
      name = this.contact.fetch_name ();
      // If we don't have a usable name use the display_name
      // to generate the color but don't show any label
      if (name == null)
        name = this.contact.fetch_display_name ();
      else
        show_initials = true;
    }

    ((Adw.Avatar) this.child).show_initials = show_initials;
    ((Adw.Avatar) this.child).text = name;

    var chunk = this.contact.get_most_relevant_chunk ("avatar", true);
    if (chunk == null)
      chunk = this.contact.create_chunk ("avatar", null);
    unowned var avatar_chunk = (AvatarChunk) chunk;
    avatar_chunk.notify["avatar"].connect ((obj, pspec) => {
      this.load_avatar.begin (avatar_chunk.avatar);
    });
    this.load_avatar.begin (avatar_chunk.avatar);
  }

  private async void load_avatar (LoadableIcon? icon) {
    if (icon == null) {
      set_paintable (null);
      return;
    }

    try {
      var stream = yield icon.load_async (this.avatar_size, null);
      var pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async (stream,
                                                                    this.avatar_size,
                                                                    this.avatar_size,
                                                                    true);
      set_paintable (Gdk.Texture.for_pixbuf (pixbuf));
    } catch (Error e) {
      warning ("Couldn't load avatar of '%s': %s", this.individual.display_name, e.message);
    }
  }

  /**
   * Manually set the avatar to the given paintable,
   * even if the contact has an avatar.
   */
  public void set_paintable (Gdk.Paintable? paintable) {
    ((Adw.Avatar) this.child).set_custom_image (paintable);
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
