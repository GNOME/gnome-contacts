/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

const int MAIN_SIZE = 128;
const int ICONS_SIZE = 64;

private class Contacts.Thumbnail : Gtk.FlowBoxChild {

  public Gdk.Texture texture { get; construct set; }

  construct {
    this.halign = Gtk.Align.CENTER;

    add_css_class ("circular");

    var avatar = new Avatar (ICONS_SIZE);
    avatar.set_paintable (this.texture);
    this.set_child (avatar);
  }

  private Thumbnail (Gdk.Texture texture) {
    Object (texture: texture);
  }

  public static async Thumbnail? for_chunk (AvatarChunk chunk) throws Error
      requires (chunk.avatar != null) {

    var stream = yield chunk.avatar.load_async (MAIN_SIZE);
    var pixbuf = yield new Gdk.Pixbuf.from_stream_async (stream);
    return new Thumbnail (Gdk.Texture.for_pixbuf (pixbuf));
  }

  public static async Thumbnail? for_file (File file) throws Error {
    var stream = yield file.read_async ();
    var pixbuf = yield new Gdk.Pixbuf.from_stream_async (stream);
    return new Thumbnail (Gdk.Texture.for_pixbuf (pixbuf));
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
public class Contacts.AvatarSelector : Adw.Dialog {

  public unowned Contact contact { get; construct set; }

  [GtkChild]
  private unowned Gtk.FlowBox thumbnail_grid;

  [GtkChild]
  private unowned Gtk.Button camera_button;

  private Xdp.Portal? portal = null;

  private Gdk.Texture? selected = null;

  static construct {
    install_action ("set-avatar", null, (Gtk.WidgetActionActivateFunc) on_set_avatar);
  }

  public AvatarSelector (Contact contact) {
    Object (contact: contact);

    this.thumbnail_grid.selected_children_changed.connect (on_thumbnails_selected);
    this.thumbnail_grid.child_activated.connect (on_thumbnail_activated);
    update_thumbnail_grid ();

    this.setup_camera_portal.begin ();
  }

  private void on_thumbnails_selected (Gtk.FlowBox thumbnail_grid) {
    var selected = thumbnail_grid.get_selected_children ();
    if (selected != null) {
      unowned var thumbnail = (Thumbnail) selected.data;
      this.selected = thumbnail.texture;
    } else {
      this.selected = null;
    }
  }

  private void on_thumbnail_activated (Gtk.FlowBox thumbnail_grid,
                                       Gtk.FlowBoxChild child) {
    unowned var thumbnail = (Thumbnail) child;
    this.selected = thumbnail.texture;
    activate_action_variant ("set-avatar", null);
  }

  private async void setup_camera_portal () {
    try {
      this.portal = new Xdp.Portal.initable_new ();
    } catch (Error e) {
      warning ("Failed to create XdpPortal instance: %s", e.message);
    }

    if (portal != null && portal.is_camera_present ()) {
      this.camera_button.sensitive = true;
    } else {
      this.camera_button.tooltip_text = _("No Camera Detected");
      this.camera_button.sensitive = false;
    }
  }

  /** Sets the selected avatar on the contact (it does _not_ save it) */
  private void on_set_avatar (string action_name, Variant? param) {
    if (this.selected == null) {
      warning ("Trying to save avatar, but none selected");
      return;
    }

    debug ("Saving avatar");
    var bytes = this.selected.save_to_png_bytes ();
    var icon = new BytesIcon (bytes);

    // Save into the most relevant avatar
    var avatar_chunk = this.contact.get_most_relevant_chunk ("avatar", true);
    if (avatar_chunk == null)
      avatar_chunk = this.contact.create_chunk ("avatar", null);
    ((AvatarChunk) avatar_chunk).avatar = icon;
    destroy ();
  }

  private void update_thumbnail_grid () {
    var filter = new ChunkFilter.for_property ("avatar");
    var chunks = new Gtk.FilterListModel (this.contact, (owned) filter);
    for (uint i = 0; i < chunks.get_n_items (); i++) {
      var chunk = (AvatarChunk) chunks.get_item (i);
      Thumbnail.for_chunk.begin (chunk, (obj, res) => {
        try {
          var thumbnail = Thumbnail.for_chunk.end (res);
          this.thumbnail_grid.insert (thumbnail, -1);
        } catch (Error e) {
          debug ("Couldn't create thumbnail for chunk: %s", e.message);
        }
      });
    }

    var stock_files = Utils.get_stock_avatars ();
    foreach (unowned var filename in stock_files) {
      var file = File.new_for_path (filename);
      Thumbnail.for_file.begin (file, (obj, res) => {
        try {
          var thumbnail = Thumbnail.for_file.end (res);
          this.thumbnail_grid.insert (thumbnail, -1);
        } catch (Error e) {
          debug ("Couldn't create thumbnail for file '%s': %s", filename, e.message);
        }
      });
    }
  }

  [GtkCallback]
  private void on_camera_button_clicked (Gtk.Button button) {
    var dialog = new CropDialog.for_portal (this.portal,
                                            this.get_root () as Gtk.Window);
    dialog.cropped.connect ((dialog, texture) => {
      this.selected = texture;
      activate_action_variant ("set-avatar", null);
      dialog.close ();
      this.close ();
    });
    dialog.present (this);
  }

  [GtkCallback]
  private void on_file_clicked (Gtk.Button button) {
    choose_file.begin ((obj, res) => { choose_file.end (res); });
  }

  private async void choose_file () {
    var file_dialog = new Gtk.FileDialog ();
    file_dialog.title = _("Browse for more pictures");
    file_dialog.accept_label = _("_Open");
    file_dialog.modal = true;

    var filters = new ListStore (typeof (Gtk.FileFilter));
    var any_image_filter = new Gtk.FileFilter ();
    any_image_filter.name = _("Image File");
    Gdk.Pixbuf.get_formats ().foreach ((format) => {
      var filter = new Gtk.FileFilter ();
      filter.name = format.get_description ();
      foreach (string mime_type in format.get_mime_types ()) {
        filter.add_mime_type (mime_type);
        any_image_filter.add_suffix (mime_type);
      }
      foreach (string extension in format.get_extensions ()) {
        filter.add_suffix (extension);
        any_image_filter.add_suffix (extension);
      }
      filters.append (filter);
    });
    filters.append (any_image_filter);
    file_dialog.filters = filters;
    file_dialog.default_filter = any_image_filter;

    unowned var pictures_folder = Environment.get_user_special_dir (UserDirectory.PICTURES);
    if (pictures_folder != null)
      file_dialog.set_initial_folder (File.new_for_path (pictures_folder));

    var parent_window = this.get_root () as Gtk.Window;
    try {
      var file = yield file_dialog.open (parent_window, null);
      var in_stream = yield file.read_async ();
      var pixbuf = yield new Gdk.Pixbuf.from_stream_async (in_stream, null);
      var texture = Gdk.Texture.for_pixbuf (pixbuf);
      in_stream.close ();

      var dialog = new CropDialog.for_paintable (texture);
      dialog.cropped.connect ((dialog, texture) => {
        this.selected = texture;
        activate_action_variant ("set-avatar", null);
        dialog.close ();
        this.close ();
      });
      dialog.present (parent_window);
    } catch (Gtk.DialogError error) {
      switch (error.code) {
        case Gtk.DialogError.CANCELLED:
        case Gtk.DialogError.DISMISSED:
          debug ("Dismissed opening file: %s", error.message);
          break;
        case Gtk.DialogError.FAILED:
        default:
          warning ("Could not open file: %s", error.message);
          break;
      }
    } catch (GLib.Error e) {
      warning ("Failed to set avatar: %s", e.message);
      var dialog = new Adw.AlertDialog (null, _("Failed to set avatar."));
      dialog.add_response ("close", _("_Close"));
      dialog.default_response = "close";
      dialog.present(this);
    }
  }
}
