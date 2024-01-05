/*
 * Copyright (C) 2018 Elias Entrup <elias-git@flump.de>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-crop-dialog.ui")]
public class Contacts.CropDialog : Adw.Window {

  [GtkChild]
  private unowned Adw.ToolbarView toolbar_view;

  private Cc.CropArea crop_area;

  public signal void cropped (Gdk.Pixbuf pixbuf);

  static construct {
    install_action ("crop", null, (Gtk.WidgetActionActivateFunc) on_crop);
  }

  construct {
    this.crop_area = new Cc.CropArea ();
    this.crop_area.vexpand = true;
    this.crop_area.hexpand = true;
    this.crop_area.set_min_size (48, 48);
    this.toolbar_view.content = this.crop_area;
  }

  public CropDialog.for_pixbuf (Gdk.Pixbuf pixbuf,
                                Gtk.Window? parent = null) {
    Object (transient_for: parent);

    this.crop_area.set_paintable (Gdk.Texture.for_pixbuf (pixbuf));
  }

  private void on_crop (string action_name, Variant? param) {
    cropped (this.crop_area.create_pixbuf ());
    destroy ();
  }
}
