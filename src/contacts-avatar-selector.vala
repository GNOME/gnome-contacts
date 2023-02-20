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

  public Thumbnail.for_chunk (AvatarChunk chunk)
      requires (chunk.avatar != null) {

   Gdk.Pixbuf? pixbuf = null;
    try {
      var stream = chunk.avatar.load (MAIN_SIZE, null);
      pixbuf = new Gdk.Pixbuf.from_stream (stream);
    } catch (Error e) {
      debug ("Couldn't create thumbnail for chunk: %s", e.message);
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
public class Contacts.AvatarSelector : Gtk.Window {

  public unowned Contact contact { get; construct set; }

  [GtkChild]
  private unowned Gtk.FlowBox thumbnail_grid;

  [GtkChild]
  private unowned Gtk.Button camera_button;

  private Xdp.Portal? portal = null;

  private Gdk.Pixbuf? _selected_avatar = null;
  public Gdk.Pixbuf? selected_avatar {
    owned get { return scale_pixbuf_for_avatar_use (this._selected_avatar); }
    private set { this._selected_avatar = value; }
  }

  static construct {
    install_action ("set-avatar", null, (Gtk.WidgetActionActivateFunc) on_set_avatar);
  }

  public AvatarSelector (Contact contact, Gtk.Window? window = null) {
    Object (contact: contact, transient_for: window);

    this.thumbnail_grid.selected_children_changed.connect (on_thumbnails_selected);
    this.thumbnail_grid.child_activated.connect (on_thumbnail_activated);
    update_thumbnail_grid ();

    this.setup_camera_portal.begin ();
  }

  private void on_thumbnails_selected (Gtk.FlowBox thumbnail_grid) {
    var selected = thumbnail_grid.get_selected_children ();
    if (selected != null) {
      unowned var thumbnail = (Thumbnail) selected.data;
      this.selected_avatar = thumbnail.source_pixbuf;
    } else {
      this.selected_avatar = null;
    }
  }

  private void on_thumbnail_activated (Gtk.FlowBox thumbnail_grid,
                                       Gtk.FlowBoxChild child) {
    unowned var thumbnail = (Thumbnail) child;
    this.selected_avatar = thumbnail.source_pixbuf;
    activate_action_variant ("set-avatar", null);
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

  private Gdk.Pixbuf? scale_pixbuf_for_avatar_use (Gdk.Pixbuf? pixbuf) {
    if (pixbuf == null)
      return null;

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

  /** Sets the selected avatar on the contact (it does _not_ save it) */
  private void on_set_avatar (string action_name, Variant? param) {
    debug ("Setting avatar");
    try {
      uint8[] buffer;
      this.selected_avatar.save_to_buffer (out buffer, "png", null);
      var icon = new BytesIcon (new Bytes (buffer));

      // Save into the most relevant avatar
      var avatar_chunk = this.contact.get_most_relevant_chunk ("avatar", true);
      if (avatar_chunk == null)
        avatar_chunk = this.contact.create_chunk ("avatar", null);
      ((AvatarChunk) avatar_chunk).avatar = icon;
      destroy ();
    } catch (Error e) {
      destroy ();

      warning ("Failed to set avatar: %s", e.message);
      var dialog = new Adw.MessageDialog (this.transient_for,
                                          null,
                                          _("Failed to set avatar"));
      dialog.add_response ("close", _("_Close"));
      dialog.show ();
    }
  }

  private void update_thumbnail_grid () {
    var filter = new ChunkFilter.for_property ("avatar");
    var chunks = new Gtk.FilterListModel (this.contact, (owned) filter);
    for (uint i = 0; i < chunks.get_n_items (); i++) {
      var chunk = (AvatarChunk) chunks.get_item (i);
      var thumbnail = new Thumbnail.for_chunk (chunk);
      if (thumbnail.source_pixbuf != null) {
        this.thumbnail_grid.insert (thumbnail, -1);
      }
    }

    var stock_files = Utils.get_stock_avatars ();
    foreach (var file_name in stock_files) {
      var thumbnail = new Thumbnail.for_filename (file_name);
      if (thumbnail.source_pixbuf != null) {
        this.thumbnail_grid.insert (thumbnail, -1);
      }
    }
  }

  [GtkCallback]
  private void on_camera_button_clicked (Gtk.Button button) {
    // XXX implement
    // var dialog = new CropDialog.for_portal (this.portal,
    //                                         this.get_root () as Gtk.Window);
    // dialog.show ();
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
          dialog.cropped.connect ((pixbuf) => {
              this.selected_avatar = pixbuf;
              activate_action_variant ("set-avatar", null);
          });
          dialog.present ();
        } else {
          this.selected_avatar = pixbuf;
          activate_action_variant ("set-avatar", null);
        }
      } catch (GLib.Error e) {
        warning ("Failed to set avatar: %s", e.message);
        var dialog = new Adw.MessageDialog (get_root () as Gtk.Window,
                                            null,
                                            _("Failed to set avatar."));
        dialog.add_response ("close", _("_Close"));
        dialog.default_response = "close";
        dialog.show();
      } finally {
        chooser.destroy ();
      }
    });
    chooser.show ();
  }
}
