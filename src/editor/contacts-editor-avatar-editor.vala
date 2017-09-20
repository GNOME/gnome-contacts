/*
 * Copyright (C) 2017 Niels De Graef <nielsdegraef@gmail.com>
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
using Gee;
using Gtk;

public class Contacts.Editor.AvatarEditor : DetailsEditor<AvatarDetails> {

  private Contact? contact;

  private Avatar avatar;

  // The button containing the Avatar
  private Button avatar_button;

  private LoadableIcon? avatar_icon = null;

  public override string persona_property {
    get { return "avatar"; }
  }

  public AvatarEditor (Contact? contact = null, AvatarDetails? details = null) {
    this.contact = contact;

    //X XXX button
    this.avatar = new Avatar (PROFILE_SIZE, contact);
    this.avatar.vexpand = false;

    this.avatar_button = new Button ();
    this.avatar_button.image = this.avatar;
    this.avatar_button.show ();
    this.avatar_button.clicked.connect (on_avatar_button_clicked);
  }

  public override int attach_to_grid (Grid container_grid, int row) {
    container_grid.attach (this.avatar_button, 0, row, 1, 3);
    return 0;
  }

  public override async void save (AvatarDetails avatar_details) throws PropertyError {
    yield avatar_details.change_avatar (this.avatar_icon);
  }

  public override Value create_value () {
    Value v = Value (this.avatar_icon.get_type ());
    v.set_object (this.avatar_icon);
    return v;
  }

  // Show the avatar dialog when the avatar is clicked
  private void on_avatar_button_clicked (Button button) {
    var dialog = new AvatarSelector ((Gtk.Window) button.get_toplevel(), this.contact);
    dialog.set_avatar.connect ( (icon) =>  {
        this.avatar_icon = icon as LoadableIcon;
        this.dirty = true;

        Gdk.Pixbuf? a_pixbuf = null;
        try {
          var stream = (icon as LoadableIcon).load (PROFILE_SIZE, null);
          a_pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, PROFILE_SIZE, PROFILE_SIZE, true);
        } catch (Error e) {
          debug ("Couldn't load the chosen avatar: %s", e.message);
        }

        this.avatar.set_pixbuf (a_pixbuf);
      });

    dialog.run ();
    dialog.destroy ();
  }
}
