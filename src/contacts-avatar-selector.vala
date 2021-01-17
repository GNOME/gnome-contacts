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
 * The AvatarSelector can be used to choose the avatar for a contact.
 * This can be done by either choosing a stock thumbnail, an image file
 * provided by the user, or -if cheese is enabled- by using a webcam.
 *
 * After a user has initially chosen an avatar, we provide a cropping tool.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-avatar-selector.ui")]
public class Contacts.AvatarSelector : Gtk.Popover {
  const int ICONS_SIZE = 64;
  const int MAIN_SIZE = 128;
  const string AVATAR_BUTTON_CSS_NAME = "avatar-button";

  // This will provide the default thumbnails
  private Gnome.DesktopThumbnailFactory thumbnail_factory;
  private Individual individual;

  [GtkChild]
  private Gtk.FlowBox personas_thumbnail_grid;
  [GtkChild]
  private Gtk.FlowBox stock_thumbnail_grid;

#if HAVE_CHEESE
  [GtkChild]
  private Gtk.Button cheese_button;
  private int num_cameras;
  private Cheese.CameraDeviceMonitor camera_monitor;
#endif

  public AvatarSelector (Gtk.Widget relative, Individual? individual) {
    this.set_relative_to(relative);
    this.thumbnail_factory = new Gnome.DesktopThumbnailFactory (Gnome.ThumbnailSize.NORMAL);
    this.individual = individual;

    update_thumbnail_grids ();

#if HAVE_CHEESE
    this.cheese_button.visible = true;
    this.cheese_button.sensitive = false;

    // Look for camera devices.
    this.camera_monitor = new Cheese.CameraDeviceMonitor ();
    this.camera_monitor.added.connect ( () => {
        this.num_cameras++;
        this.cheese_button.sensitive = (this.num_cameras > 0);
      });
    this.camera_monitor.removed.connect ( () => {
        this.num_cameras--;
        this.cheese_button.sensitive = (this.num_cameras > 0);
      });
    // Do this in a separate thread, or it blocks the whole UI
    new Thread<void*> ("camera-loader", () => {
        this.camera_monitor.coldplug ();
        return null;
      });
#endif
  }

  private Gdk.Pixbuf scale_pixbuf_for_avatar_use (Gdk.Pixbuf pixbuf) {
    int w = pixbuf.get_width ();
    int h = pixbuf.get_height ();

    if (w <= MAIN_SIZE && h <= MAIN_SIZE)
      return pixbuf;

    if (w > h) {
      h = (int)Math.round (h * (float) MAIN_SIZE / w);
      w = MAIN_SIZE;
    } else {
      w = (int)Math.round (w * (float) MAIN_SIZE / h);
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
      this.individual.change_avatar.begin(icon as LoadableIcon, (obj, res) => {
        try {
          this.individual.change_avatar.end(res);
        } catch (Error e) {
          warning ("Failed to set avatar: %s", e.message);
          Utils.show_error_dialog (_("Failed to set avatar."),
                                   get_toplevel() as Gtk.Window);
        }
      });
    } catch (GLib.Error e) {
      warning ("Failed to set avatar: %s", e.message);
      Utils.show_error_dialog (_("Failed to set avatar."),
                               get_toplevel() as Gtk.Window);
    }
  }

  private Gtk.FlowBoxChild create_thumbnail (Gdk.Pixbuf source_pixbuf) {
    var avatar = new Avatar (ICONS_SIZE);
    avatar.set_pixbuf (source_pixbuf);

    var button = new Gtk.Button ();
    button.get_style_context ().add_class (AVATAR_BUTTON_CSS_NAME);
    button.image = avatar;
    button.clicked.connect ( () => {
        selected_pixbuf (scale_pixbuf_for_avatar_use (source_pixbuf));
        this.popdown ();
      });
    var child = new Gtk.FlowBoxChild ();
    child.add (button);
    child.set_halign (Gtk.Align.START);

    return child;
  }

  private Gtk.FlowBoxChild? thumbnail_for_persona (Persona persona) {
    var details = persona as AvatarDetails;
    if (details == null || details.avatar == null)
      return null;

    try {
      var stream = details.avatar.load (MAIN_SIZE, null);
      return create_thumbnail (new Gdk.Pixbuf.from_stream (stream));
    } catch (Error e) {
      debug ("Couldn't create frame for persona '%s': %s", persona.display_id, e.message);
    }

    return null;
  }

  private Gtk.FlowBoxChild? thumbnail_for_filename (string filename) {
    try {
      return create_thumbnail (new Gdk.Pixbuf.from_file (filename));
    } catch (Error e) {
      debug ("Couldn't create frame for file '%s': %s", filename, e.message);
    }

    return null;
  }

  private void update_thumbnail_grids () {
    if (this.individual != null) {
      foreach (var p in individual.personas) {
        var button = thumbnail_for_persona (p);
        if (button != null)
          this.personas_thumbnail_grid.add (button);
      }
    }
    this.personas_thumbnail_grid.show_all ();

    var stock_files = Utils.get_stock_avatars ();
    foreach (var file_name in stock_files) {
      var button = thumbnail_for_filename (file_name);
      if (button != null)
        this.stock_thumbnail_grid.add (button);
    }
    this.stock_thumbnail_grid.show_all ();
  }

  [GtkCallback]
  private void on_cheese_clicked (Gtk.Button button) {
    var dialog = new CropCheeseDialog.for_cheese (get_toplevel() as Gtk.Window);
    dialog.show_all ();
    dialog.picture_selected.connect ( (pix) => {
      selected_pixbuf (scale_pixbuf_for_avatar_use (pix));
    });
    this.popdown ();
  }

  [GtkCallback]
  private void on_file_clicked (Gtk.Button button) {
    var chooser = new Gtk.FileChooserNative (_("Browse for more pictures"),
                                             get_toplevel () as Gtk.Window,
                                             Gtk.FileChooserAction.OPEN,
                                             _("_Open"), _("_Cancel"));
    chooser.set_modal (true);
    chooser.set_local_only (false);
    var preview = new Gtk.Image ();
    preview.set_size_request (MAIN_SIZE, -1);
    chooser.set_preview_widget (preview);
    chooser.set_use_preview_label (false);
    preview.show ();

    chooser.update_preview.connect (update_preview);

    var folder = Environment.get_user_special_dir (UserDirectory.PICTURES);
    if (folder != null)
      chooser.set_current_folder (folder);

    chooser.response.connect ( (response) => {
        if (response != Gtk.ResponseType.ACCEPT) {
          chooser.destroy ();
          return;
        }
        try {
          var file = File.new_for_uri (chooser.get_uri ());
          var in_stream = file.read ();
          var pixbuf = new Gdk.Pixbuf.from_stream (in_stream, null);
          in_stream.close ();
          if (pixbuf.get_width () > MAIN_SIZE || pixbuf.get_height () > MAIN_SIZE) {
            var dialog = new CropCheeseDialog.for_crop (get_toplevel () as Gtk.Window,
                                                        pixbuf);
            dialog.picture_selected.connect ( (pix) => {
              selected_pixbuf (scale_pixbuf_for_avatar_use (pix));
            });
            dialog.show_all();
          } else {
            selected_pixbuf (scale_pixbuf_for_avatar_use (pixbuf));
          }
        } catch (GLib.Error e) {
          warning ("Failed to set avatar: %s", e.message);
          Utils.show_error_dialog (_("Failed to set avatar."),
                                   this.get_toplevel() as Gtk.Window);
        }

        chooser.destroy ();
      });

    chooser.run ();
    this.popdown();
  }

  private void update_preview (Gtk.FileChooser chooser) {
    var uri = chooser.get_preview_uri ();
    if (uri != null) {
      Gdk.Pixbuf? pixbuf = null;

      var preview = chooser.get_preview_widget () as Gtk.Image;

      var file = File.new_for_uri (uri);
      try {
        var file_info = file.query_info (FileAttribute.STANDARD_CONTENT_TYPE,
                         FileQueryInfoFlags.NONE, null);
        if (file_info != null) {
          var mime_type = file_info.get_content_type ();

          if (mime_type != null)
            pixbuf = this.thumbnail_factory.generate_thumbnail (uri, mime_type);
        }
      } catch (Error e) {
        debug ("Couldn't generate thumbnail for file '%s': %s", uri, e.message);
      }

      if (chooser is Gtk.Dialog)
        ((Gtk.Dialog) chooser).set_response_sensitive (Gtk.ResponseType.ACCEPT,
                                                       (pixbuf != null));

      if (pixbuf != null)
        preview.set_from_pixbuf (pixbuf);
      else
        preview.set_from_icon_name ("dialog-question", Gtk.IconSize.DIALOG);
    }

    chooser.set_preview_widget_active (true);
  }

}
