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

const int MAIN_SIZE = 128;
const int ICONS_SIZE = 64;

private class Contacts.Thumbnail : Gtk.FlowBoxChild {

  public Gdk.Pixbuf? source_pixbuf { get; construct set; }

  private Thumbnail (Gdk.Pixbuf? source_pixbuf = null) {
    Object (visible: true,
            halign: Gtk.Align.CENTER,
            source_pixbuf: source_pixbuf);

    this.add_css_class ("circular");

    var avatar = new Avatar (ICONS_SIZE);
    avatar.set_pixbuf (source_pixbuf);
    this.set_child (avatar);
  }

  public Thumbnail.for_persona (Persona persona) {
    Gdk.Pixbuf? pixbuf = null;
    unowned var details = persona as AvatarDetails;
    if (details != null && details.avatar != null) {
      try {
        var stream = details.avatar.load (MAIN_SIZE, null);
        pixbuf = new Gdk.Pixbuf.from_stream (stream);
      } catch (Error e) {
        debug ("Couldn't create frame for persona '%s': %s", persona.display_id, e.message);
      }
    }
    this (pixbuf);
  }

  public Thumbnail.for_filename (string filename) {
    Gdk.Pixbuf? pixbuf = null;
    try {
      pixbuf = new Gdk.Pixbuf.from_file (filename);
    } catch (Error e) {
      debug ("Couldn't create frame for file '%s': %s", filename, e.message);
    }
    this (pixbuf);
  }
}

/**
 * The AvatarSelector can be used to choose the avatar for a contact.
 * This can be done by either choosing a stock thumbnail, an image file
 * provided by the user, or by using a webcam.
 *
 * After a user has initially chosen an avatar, we provide a cropping tool.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-avatar-selector.ui")]
public class Contacts.AvatarSelector : Gtk.Dialog {

  const string AVATAR_BUTTON_CSS_NAME = "avatar-button";

  private unowned Individual individual;

  [GtkChild]
  private unowned Gtk.FlowBox thumbnail_grid;

  [GtkChild]
  private unowned Gtk.Button camera_button;

  private Xdp.Portal? portal = null;

  public AvatarSelector (Individual? individual, Gtk.Window? window = null) {
    Object (transient_for: window, use_header_bar: 1);
    this.individual = individual;

    update_thumbnail_grid ();

    this.setup_camera_portal.begin ();
  }

  private async void setup_camera_portal () {
    this.portal = new Xdp.Portal ();

    if (portal.is_camera_present ()) {
      this.camera_button.sensitive = true;
    } else {
      this.camera_button.tooltip_text = _("No Camera Detected");
      this.camera_button.sensitive = false;
    }
  }

  private Gdk.Pixbuf scale_pixbuf_for_avatar_use (Gdk.Pixbuf pixbuf) {
    int w = pixbuf.get_width ();
    int h = pixbuf.get_height ();

    if (w <= MAIN_SIZE && h <= MAIN_SIZE)
      return pixbuf;

    if (w > h) {
      h = (int) Math.round (h * (float) MAIN_SIZE / w);
      w = MAIN_SIZE;
    } else {
      w = (int) Math.round (w * (float) MAIN_SIZE / h);
      h = MAIN_SIZE;
    }

    return pixbuf.scale_simple (w, h, Gdk.InterpType.HYPER);
  }

  private void selected_pixbuf (Gdk.Pixbuf pixbuf) {
    try {
      uint8[] buffer;
      pixbuf.save_to_buffer (out buffer, "png", null);
      var icon = new BytesIcon (new Bytes (buffer));
      // Set the new avatar
      this.individual.change_avatar.begin (icon as LoadableIcon, (obj, res) => {
        try {
          this.individual.change_avatar.end (res);
        } catch (Error e) {
          warning ("Failed to set avatar: %s", e.message);
          Utils.show_error_dialog (_("Failed to set avatar."),
                                   get_root () as Gtk.Window);
        }
      });
    } catch (GLib.Error e) {
      warning ("Failed to set avatar: %s", e.message);
      Utils.show_error_dialog (_("Failed to set avatar."),
                               get_root () as Gtk.Window);
    }
  }

  private void update_thumbnail_grid () {
    if (this.individual != null) {
      foreach (var p in individual.personas) {
        var widget = new Thumbnail.for_persona (p);
        if (widget.source_pixbuf != null)
          this.thumbnail_grid.insert (widget, -1);
      }
    }

    var stock_files = Utils.get_stock_avatars ();
    foreach (var file_name in stock_files) {
      var widget = new Thumbnail.for_filename (file_name);
      if (widget.source_pixbuf != null)
        this.thumbnail_grid.insert (widget, -1);
    }
  }

  [GtkCallback]
  private void on_camera_button_clicked (Gtk.Button button) {
    // XXX implement
    // var dialog = new CropDialog.for_portal (this.portal,
    //                                         this.get_root () as Gtk.Window);
    // dialog.show ();
  }

  public override void response (int response) {
    if (response == Gtk.ResponseType.OK) {
      var selected_children = thumbnail_grid.get_selected_children ();
      if (selected_children != null) {
        unowned var thumbnail = (selected_children.data as Thumbnail);
        if (thumbnail != null)
          selected_pixbuf (scale_pixbuf_for_avatar_use (thumbnail.source_pixbuf));
      }
    }

    this.close ();
  }

  [GtkCallback]
  private void on_file_clicked (Gtk.Button button) {
    var chooser = new Gtk.FileChooserNative (_("Browse for more pictures"),
                                             this.get_root () as Gtk.Window,
                                             Gtk.FileChooserAction.OPEN,
                                             _("_Open"), _("_Cancel"));
    chooser.set_modal (true);

    try {
      unowned var pictures_folder = Environment.get_user_special_dir (UserDirectory.PICTURES);
      if (pictures_folder != null)
        chooser.set_current_folder (File.new_for_path (pictures_folder));
    } catch (Error e) {
      warning ("Couldn't set avatar selector to Pictures folder: %s", e.message);
    }

    chooser.response.connect ((response) => {
      if (response != Gtk.ResponseType.ACCEPT) {
        chooser.destroy ();
        return;
      }

      try {
        var file = chooser.get_file ();
        var in_stream = file.read ();
        var pixbuf = new Gdk.Pixbuf.from_stream (in_stream, null);
        in_stream.close ();
        if (pixbuf.get_width () > MAIN_SIZE || pixbuf.get_height () > MAIN_SIZE) {
          var dialog = new CropDialog.for_pixbuf (pixbuf,
                                                  get_root () as Gtk.Window);
          dialog.response.connect ((response) => {
              if (response == Gtk.ResponseType.ACCEPT) {
                var cropped = dialog.create_pixbuf ();
                selected_pixbuf (scale_pixbuf_for_avatar_use (cropped));
              }
              dialog.destroy ();
          });
          dialog.show ();
        } else {
          selected_pixbuf (scale_pixbuf_for_avatar_use (pixbuf));
        }
      } catch (GLib.Error e) {
        warning ("Failed to set avatar: %s", e.message);
        Utils.show_error_dialog (_("Failed to set avatar."),
                                 this.get_root () as Gtk.Window);
      } finally {
        chooser.destroy ();
      }
    });
    chooser.show ();
  }
}
