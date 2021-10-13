/*
 * Copyright (C) 2018 Elias Entrup <elias-git@flump.de>
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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-crop-dialog.ui")]
public class Contacts.CropDialog : Gtk.Dialog {

  [GtkChild]
  private unowned Gtk.Box box;

  private Cc.CropArea crop_area;

  construct {
    this.crop_area = new Cc.CropArea ();
    this.crop_area.vexpand = true;
    this.crop_area.hexpand = true;
    this.crop_area.set_min_size (48, 48);
    this.box.append (this.crop_area);
  }

  public CropDialog.for_pixbuf (Gdk.Pixbuf pixbuf, Gtk.Window? parent = null) {
    Object (use_header_bar: 1, transient_for: parent);

    this.crop_area.set_paintable (Gdk.Texture.for_pixbuf (pixbuf));
  }

  public Gdk.Pixbuf create_pixbuf () {
    return this.crop_area.create_pixbuf ();
  }
}
