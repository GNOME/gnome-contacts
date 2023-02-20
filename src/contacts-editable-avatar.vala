/*
 * Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
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
 * The EditableAvatar is a custom widget that allows changing or unsetting a
 * {@link Contact}'s avatar.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-editable-avatar.ui")]
public class Contacts.EditableAvatar : Gtk.Widget {

  [GtkChild]
  private unowned Gtk.Overlay overlay;

  public Contact contact { get; construct; }

  public int avatar_size { get; set; }

  static construct {
    set_layout_manager_type (typeof (Gtk.BinLayout));

    install_action ("edit-avatar", null, (Gtk.WidgetActionActivateFunc) on_edit_avatar);
    install_action ("delete-avatar", null, (Gtk.WidgetActionActivateFunc) on_delete_avatar);
  }

  construct {
    var avatar = new Avatar.for_contact (this.avatar_size, this.contact);
    this.bind_property ("avatar-size", avatar, "avatar-size");
    this.overlay.child = avatar;

    var chunk = this.contact.get_most_relevant_chunk ("avatar", true);
    if (chunk == null)
      chunk = this.contact.create_chunk ("avatar", null);
    unowned var avatar_chunk = (AvatarChunk) chunk;
    action_set_enabled ("delete-avatar", avatar_chunk.avatar != null);
    avatar_chunk.notify["avatar"].connect (on_avatar_chunk_notify);
  }

  public EditableAvatar (Contact contact, int size) {
    Object (contact: contact, avatar_size: size);
  }

  public override void dispose () {
    this.overlay.unparent ();
    base.dispose ();
  }

  private void on_avatar_chunk_notify (Object object, ParamSpec pspec) {
    unowned var avatar_chunk = (AvatarChunk) object;
    action_set_enabled ("delete-avatar", avatar_chunk.avatar != null);
  }

  private void on_edit_avatar (string action_name, Variant? param) {
    var selector = new AvatarSelector (this.contact,
                                       get_root () as Gtk.Window);
    selector.present ();
  }

  private void on_delete_avatar (string action_name, Variant? param) {
    var avatar_chunk = this.contact.get_most_relevant_chunk ("avatar", true);
    if (avatar_chunk == null)
      avatar_chunk = this.contact.create_chunk ("avatar", null);
    ((AvatarChunk) avatar_chunk).avatar = null;
  }
}
