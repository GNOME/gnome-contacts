/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
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

/**
 * The AvatarDialog can be used to choose the avatar for a contact.
 * This can be done by choosing from:
 * - one of the contact's avatar,
 * - an image file on the user's machine
 * - (if cheese is enabled) a webcam.
 * - a fallback avatar
 *
 * After a user has initially chosen an avatar, we provide a cropping tool.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-avatar-dialog.ui")]
public class Contacts.AvatarPopover : Popover {
  const int MAIN_SIZE = 128;
  const int ICONS_SIZE = 64;

  private Contact contact;

  [GtkChild]
  private Stack views_stack;
  [GtkChild]
  private FlowBox personas_thumbnail_grid;
  [GtkChild]
  private Grid crop_page;
  private Cc.CropArea crop_area;
  [GtkChild]
  private Grid photobooth_page;
  [GtkChild]
  private Button webcam_button;

  private ContactFrame current_avatar;

#if HAVE_CHEESE
  private Cheese.Flash flash;
  private Cheese.CameraDeviceMonitor camera_monitor;
  private Cheese.Widget cheese;
  private int num_cameras;
#endif

  private Gdk.Pixbuf? new_pixbuf;

  /**
   * Fired after the user has definitely chosen a new avatar.
   */
  public signal void set_avatar (GLib.Icon avatar_icon);

  public AvatarPopover (Widget? relative_to, Contact? contact) {
    Object (
      relative_to: relative_to,
      modal: true
    );

    this.contact = contact;

    // Load the current avatar
    this.current_avatar = new ContactFrame (MAIN_SIZE);
    if (contact != null) {
      contact.keep_widget_uptodate (this.current_avatar, (w) => {
          (w as ContactFrame).set_image (contact.individual, contact);
        });
    } else {
      this.current_avatar.set_image (null, null);
    }
    this.current_avatar.set_hexpand (false);
    this.current_avatar.show ();
    /* this.grid.attach (this.current_avatar, 0, 0); */


#if HAVE_CHEESE
    // Look for camera devices.
    this.camera_monitor = new Cheese.CameraDeviceMonitor ();
    this.camera_monitor.added.connect ( () => {
        this.num_cameras++;
        this.webcam_button.sensitive = (this.num_cameras > 0);
      });
    this.camera_monitor.removed.connect ( () => {
        this.num_cameras--;
        this.webcam_button.sensitive = (this.num_cameras > 0);
      });
    // Do this in a separate thread, or it blocks the whole UI
    new Thread<void*> ("camera-loader", () => {
        this.camera_monitor.coldplug ();
        return null;
      });

    // Create a photobooth page
    this.cheese = new Cheese.Widget ();
    this.cheese.set_vexpand (true);
    this.cheese.set_hexpand (true);
    this.cheese.set_no_show_all (true);
    this.photobooth_page.attach (cheese, 0, 0);
    this.photobooth_page.show ();

    this.flash = new Cheese.Flash (this);
#endif

    this.views_stack.set_visible_child_name ("thumbnail-page");
    /*
    var remove_button = new ToolButton (null, null);
    remove_button.set_icon_name ("list-remove-symbolic");
    remove_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    remove_button.is_important = true;
    toolbar.add (remove_button);
    remove_button.clicked.connect ( (button) => {
       });
    */

    update_thumbnail_grid ();
  }

  private Gdk.Pixbuf scale_pixbuf_for_avatar_use (Gdk.Pixbuf pixbuf) {
    int w = pixbuf.get_width ();
    int h = pixbuf.get_height ();

    if (w <= 128 && h <= 128)
      return pixbuf;

    if (w > h) {
      h = (int)Math.round (h * 128.0 / w);
      w = 128;
    } else {
      w = (int)Math.round (w * 128.0 / h);
      h = 128;
    }

    return pixbuf.scale_simple (w, h, Gdk.InterpType.HYPER);
  }

  private ContactFrame create_frame (Gdk.Pixbuf source_pixbuf) {
    var image_frame = new ContactFrame (ICONS_SIZE, true);
    var pixbuf = source_pixbuf.scale_simple (ICONS_SIZE, ICONS_SIZE, Gdk.InterpType.HYPER);
    image_frame.set_pixbuf (pixbuf);
    var avatar_pixbuf = scale_pixbuf_for_avatar_use (source_pixbuf);
    image_frame.clicked.connect ( () => {
        selected_pixbuf (avatar_pixbuf);
      });
    return image_frame;
  }

  private ContactFrame? frame_for_persona (Persona persona) {
    var details = persona as AvatarDetails;
    if (details == null || details.avatar == null)
      return null;

    try {
      var stream = details.avatar.load (128, null);
      var pixbuf = new Gdk.Pixbuf.from_stream (stream);
      return create_frame (pixbuf);
    }
    catch {
    }

    return null;
  }

  private void selected_pixbuf (Gdk.Pixbuf pixbuf) {
    var p = pixbuf.scale_simple (MAIN_SIZE, MAIN_SIZE, Gdk.InterpType.HYPER);
    this.current_avatar.set_pixbuf (p);

    this.new_pixbuf = pixbuf;
  }

  private void update_thumbnail_grid () {
    if (this.contact != null) {
      foreach (var p in contact.individual.personas) {
        ContactFrame? frame = frame_for_persona (p);
        if (frame != null)
          this.personas_thumbnail_grid.add (frame);
      }
    }
    this.personas_thumbnail_grid.show_all ();
  }

  public void update_preview (FileChooser chooser) {
    var uri = chooser.get_preview_uri ();
    if (uri != null) {
      Gdk.Pixbuf? pixbuf = null;

      var preview = chooser.get_preview_widget () as Image;

      var file = File.new_for_uri (uri);
      try {
        var file_info = file.query_info (FileAttribute.STANDARD_CONTENT_TYPE,
                         FileQueryInfoFlags.NONE, null);
        if (file_info != null) {
          var mime_type = file_info.get_content_type ();

              //XXX FIXME do this without gnome-desktop pls
          /* if (mime_type != null) */
          /*   pixbuf = thumbnail_factory.generate_thumbnail (uri, mime_type); */
        }
      } catch (GLib.Error e) {
      }

      (chooser as Dialog).set_response_sensitive (ResponseType.ACCEPT, (pixbuf != null));

      if (pixbuf != null)
        preview.set_from_pixbuf (pixbuf);
      else
        preview.set_from_icon_name ("dialog-question", IconSize.DIALOG);
    }

    chooser.set_preview_widget_active (true);
  }

  private void set_crop_widget (Gdk.Pixbuf pixbuf) {
    this.crop_area = new Cc.CropArea ();
    this.crop_area.set_vexpand (true);
    this.crop_area.set_hexpand (true);
    this.crop_area.set_min_size (48, 48);
    this.crop_area.set_constrain_aspect (true);
    this.crop_area.set_picture (pixbuf);

    this.crop_page.attach (this.crop_area, 0, 0);
    this.crop_page.show_all ();

    this.views_stack.set_visible_child_name ("crop-page");
  }

  /* public override void response (int response_id) {*/
  /*   if (response_id == ResponseType.OK && this.new_pixbuf != null) {*/
  /*     try {*/
  /*       uint8[] buffer;*/
  /*       if (this.new_pixbuf.save_to_buffer (out buffer, "png", null)) {*/
  /*         var icon = new BytesIcon (new Bytes (buffer));*/
  /*         set_avatar (icon);*/
  /*       } else {*/
           /* Failure. Fall through. */
  /*       }*/
  /*     } catch {*/
  /*     }*/
  /*   }*/

/* #if HAVE_CHEESE*/
     /* Ensure the Vala garbage collector disposes of the Cheese widget.
      * This prevents the 'Device or resource busy' warnings, see:
      *   https://bugzilla.gnome.org/show_bug.cgi?id=700959
      */
  /*   this.cheese = null;*/
/* #endif*/

  /*   this.destroy ();*/
  /* }*/

  [GtkCallback]
  private void select_avatar_file_cb (Button button) {
    var chooser = new FileChooserDialog (_("Browse for more pictures"),
                                         (Gtk.Window)this.get_toplevel (),
                                         FileChooserAction.OPEN,
                                         _("_Cancel"), ResponseType.CANCEL,
                                         _("_Open"), ResponseType.ACCEPT);
    chooser.set_modal (true);
    chooser.set_local_only (false);
    var preview = new Image ();
    preview.set_size_request (128, -1);
    chooser.set_preview_widget (preview);
    chooser.set_use_preview_label (false);
    preview.show ();

    chooser.update_preview.connect (update_preview);

    var folder = Environment.get_user_special_dir (UserDirectory.PICTURES);
    if (folder != null)
      chooser.set_current_folder (folder);

    chooser.response.connect ( (response) => {
        if (response != ResponseType.ACCEPT) {
          chooser.destroy ();
          return;
        }
        try {
          var file = File.new_for_uri (chooser.get_uri ());
          var in_stream = file.read ();
          var pixbuf = new Gdk.Pixbuf.from_stream (in_stream, null);
          in_stream.close ();
          if (pixbuf.get_width () > 128 || pixbuf.get_height () > 128)
            set_crop_widget (pixbuf);
          else
            selected_pixbuf (scale_pixbuf_for_avatar_use (pixbuf));

          update_thumbnail_grid ();
        } catch {
        }

        chooser.destroy ();
      });

    chooser.present ();
  }

  [GtkCallback]
  private void on_webcam_button_clicked (Button button) {
#if HAVE_CHEESE
    this.views_stack.set_visible_child_name ("photobooth-page");
    this.cheese.show ();
#endif
  }

  [GtkCallback]
  private void on_photobooth_page_select_button_clicked (Button button) {
#if HAVE_CHEESE
    var camera = this.cheese.get_camera () as Cheese.Camera;
    this.flash.fire ();
    camera.photo_taken.connect ( (pix) => {
        set_crop_widget (pix);
        this.cheese.hide ();
      });

    if (!camera.take_photo_pixbuf ())
      warning ("Unable to take photo");
#endif
  }

  [GtkCallback]
  private void on_photobooth_page_cancel_button_clicked (Button button) {
#if HAVE_CHEESE
    this.views_stack.set_visible_child_name ("thumbnail-page");
    this.cheese.hide ();
#endif
  }

  [GtkCallback]
  private void on_crop_page_select_button_clicked (Button button) {
    var pix = crop_area.get_picture ();
    selected_pixbuf (scale_pixbuf_for_avatar_use (pix));
    this.crop_area.destroy ();
    this.views_stack.set_visible_child_name ("thumbnail-page");
  }

  [GtkCallback]
  private void on_crop_page_cancel_button_clicked (Button button) {
    this.crop_area.destroy ();
    this.views_stack.set_visible_child_name ("thumbnail-page");
  }
}
