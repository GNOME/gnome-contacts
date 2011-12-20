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
using Gee;

public class Contacts.AvatarMenu : Gtk.Menu {
  private Gnome.DesktopThumbnailFactory thumbnail_factory;

  private Gtk.MenuItem? menu_item_for_pixbuf (Gdk.Pixbuf? pixbuf, Icon icon) {
    if (pixbuf == null)
      return null;

    var image = new Image.from_pixbuf (Contact.frame_icon (pixbuf));
    var menuitem = new Gtk.MenuItem ();
    menuitem.add (image);
    menuitem.show_all ();
    menuitem.set_data ("source-icon", icon);

    return menuitem;
  }

  private Gtk.MenuItem? menu_item_for_persona (Persona persona) {
    var details = persona as AvatarDetails;
    if (details == null || details.avatar == null)
      return null;

    try {
      var stream = details.avatar.load (48, null);
      var pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, 48, 48, true);
      return menu_item_for_pixbuf (pixbuf, details.avatar);
    }
    catch {
    }
    return null;
  }

  private Gtk.MenuItem? menu_item_for_filename (string filename) {
    try {
      var pixbuf = new Gdk.Pixbuf.from_file (filename);
      pixbuf = pixbuf.scale_simple (48, 48, Gdk.InterpType.HYPER);
      return menu_item_for_pixbuf (pixbuf, new FileIcon (File.new_for_path (filename)));
    } catch {
    }
    return null;
  }

  public signal void icon_set (Icon icon);

  private void set_avatar_from_icon (Icon icon) {
    icon_set (icon);
  }

  private void pick_avatar_cb (Gtk.MenuItem menu) {
    Icon icon = menu.get_data<Icon> ("source-icon");
    set_avatar_from_icon (icon);
  }

  public void update_preview (FileChooser chooser) {
    var uri = chooser.get_preview_uri ();
    if (uri != null) {
      Gdk.Pixbuf? pixbuf = null;

      var preview = chooser.get_preview_widget () as Image;

      var file = File.new_for_uri (uri);
      try {
	var file_info = file.query_info (GLib.FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE,
					 FileQueryInfoFlags.NONE, null);
	if (file_info != null) {
	  var mime_type = file_info.get_content_type ();

	  if (mime_type != null)
	    pixbuf = thumbnail_factory.generate_thumbnail (uri, mime_type);
	}
      } catch (GLib.Error e) {
      }

      (chooser as Dialog).set_response_sensitive (ResponseType.ACCEPT,
						  (pixbuf != null));

      if (pixbuf != null)
	preview.set_from_pixbuf (pixbuf);
      else
	preview.set_from_stock (Stock.DIALOG_QUESTION,
				IconSize.DIALOG);
    }

    chooser.set_preview_widget_active (true);
  }

  private void select_avatar_file_cb (Gtk.MenuItem menu) {
    var chooser = new FileChooserDialog (_("Browse for more pictures"),
					 (Window)this.get_toplevel (),
					 FileChooserAction.OPEN,
					 Stock.CANCEL, ResponseType.CANCEL,
					 Stock.OPEN, ResponseType.ACCEPT);
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
	var icon = new FileIcon (File.new_for_uri (chooser.get_uri ()));
	set_avatar_from_icon (icon);
	chooser.destroy ();
      });

    chooser.present ();
  }

  public AvatarMenu (Contact contact) {
    thumbnail_factory = new Gnome.DesktopThumbnailFactory (Gnome.ThumbnailSize.NORMAL);

    this.get_style_context ().add_class ("contact-frame-menu");

    int x = 0;
    int y = 0;
    const int COLUMNS = 5;

    foreach (var p in contact.individual.personas) {
      var menuitem = menu_item_for_persona (p);
      if (menuitem != null) {
	this.attach (menuitem,
		     x, x + 1, y, y + 1);
	menuitem.show ();
	menuitem.activate.connect (pick_avatar_cb);
	x++;
	if (x >= COLUMNS) {
	  y++;
	  x = 0;
	}
      }
    }

    var system_data_dirs = Environment.get_system_data_dirs ();
    foreach (var data_dir in system_data_dirs) {
      var path = Path.build_filename (data_dir, "pixmaps", "faces");
      Dir? dir = null;
      try {
	dir = Dir.open (path);
      }	catch {
      }
      if (dir != null) {
	string? face;
	while ((face = dir.read_name ()) != null) {
	  var filename = Path.build_filename (path, face);
	  var menuitem = menu_item_for_filename (filename);
	  this.attach (menuitem,
		       x, x + 1, y, y + 1);
	  menuitem.show ();
	  menuitem.activate.connect (pick_avatar_cb);
	  x++;
	  if (x >= COLUMNS) {
	    y++;
	    x = 0;
	  }
	}
      }
    };

    Utils.add_menu_item (this,_("Browse for more pictures...")).activate.connect (select_avatar_file_cb);
  }
}
