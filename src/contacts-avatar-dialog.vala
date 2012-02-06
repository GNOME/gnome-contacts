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

public class Contacts.AvatarDialog : Dialog {
  private Gnome.DesktopThumbnailFactory thumbnail_factory;
  const int main_size = 96;
  const int icons_size = 64;
  private Contact contact;
  private Grid frame_grid;
  private ScrolledWindow scrolled;
  private ToolButton add_button;
  private ToolButton crop_button;
  private ToolButton cancel_button;
  private Grid view_grid;
  private ContactFrame main_frame;

  private Gdk.Pixbuf? new_pixbuf;

  public signal void set_avatar (GLib.Icon avatar_icon);

  Gdk.Pixbuf scale_pixbuf_for_avatar_use (Gdk.Pixbuf pixbuf) {
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
    var image_frame = new ContactFrame (icons_size, true);
    var pixbuf = source_pixbuf.scale_simple (icons_size, icons_size, Gdk.InterpType.HYPER);
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

  private ContactFrame? frame_for_filename (string filename) {
    ContactFrame? image_frame = null;
    try {
      var pixbuf = new Gdk.Pixbuf.from_file (filename);
      return create_frame (pixbuf);
    } catch {
    }
    return image_frame;
  }

  private void selected_pixbuf (Gdk.Pixbuf pixbuf) {
    try {
      var p = pixbuf.scale_simple (main_size, main_size, Gdk.InterpType.HYPER);
      main_frame.set_pixbuf (p);

      new_pixbuf = pixbuf;
    } catch {
    }
  }

  private void update_grid () {
    int i = 0;
    int j = 0;

    foreach (var p in contact.individual.personas) {
      ContactFrame? frame = frame_for_persona (p);
      if (frame != null) {
	view_grid.attach (frame, i, j, 1, 1);
	i++;
	if (i >= 4) {
	  i -= 4;
	  j++;
	}
      }
    }

    if (i != 0) {
      i = 0;
      j++;
    }

    if (j != 0) {
      var s = new Separator (Orientation.HORIZONTAL);
      view_grid.attach (s, 0, j++, 4, 1);
    }

    var stock_files = Utils.get_stock_avatars ();
    foreach (var file_name in stock_files) {
      ContactFrame? frame = frame_for_filename (file_name);
      if (frame != null) {
	view_grid.attach (frame, i, j, 1, 1);
	i++;
	if (i >= 4) {
	  i -= 4;
	  j++;
	}
      }
    }

    view_grid.show_all ();
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

  private void select_avatar_file_cb () {
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
	try {
	  var file = File.new_for_uri (chooser.get_uri ());
	  var in_stream = file.read ();
	  var pixbuf = new Gdk.Pixbuf.from_stream (in_stream, null);
	  in_stream.close ();
	  if (pixbuf.get_width () > 128 || pixbuf.get_height () > 128) {
	    var crop_area = new Um.CropArea ();
	    crop_area.set_vexpand (true);
	    crop_area.set_hexpand (true);
	    crop_area.set_min_size (48, 48);
	    crop_area.set_constrain_aspect (true);
	    crop_area.set_picture (pixbuf);
	    frame_grid.attach_next_to (crop_area, scrolled, PositionType.TOP, 1, 1);
	    crop_area.show ();
	    crop_button.show ();
	    crop_button.clicked.connect ((button) => {
		var pix = crop_area.get_picture ();
		selected_pixbuf (scale_pixbuf_for_avatar_use (pix));
		crop_area.destroy ();
		crop_button.hide ();
		cancel_button.hide ();

		scrolled.show ();
		add_button.show ();
	      });
	    cancel_button.show ();
	    cancel_button.clicked.connect ((button) => {
		crop_button.hide ();
		cancel_button.hide ();

		scrolled.show ();
		add_button.show ();
	      });
	    add_button.hide ();
	    scrolled.hide ();
	  } else
	    selected_pixbuf (scale_pixbuf_for_avatar_use (pixbuf));

	  update_grid ();
	} catch {
	}

	chooser.destroy ();
      });

    chooser.present ();
  }


  public AvatarDialog (Contact contact) {
    thumbnail_factory = new Gnome.DesktopThumbnailFactory (Gnome.ThumbnailSize.NORMAL);
    this.contact = contact;
    set_title (_("Select Picture"));
    set_transient_for (App.app.window);
    set_modal (true);
    add_buttons (_("Close"), ResponseType.CLOSE, null);

    var grid = new Grid ();
    grid.set_border_width (8);
    grid.set_column_spacing (8);
    var container = (get_content_area () as Container);
    container.add (grid);

    main_frame = new ContactFrame (main_size);
    contact.keep_widget_uptodate (main_frame, (w) => {
	(w as ContactFrame).set_image (contact.individual, contact);
      });
    main_frame.set_hexpand (false);
    grid.attach (main_frame, 0, 0, 1, 1);

    var label = new Label ("");
    label.set_markup ("<span font='13'>" + contact.display_name + "</span>");
    label.set_valign (Align.START);
    label.set_halign (Align.START);
    label.set_hexpand (true);
    label.xalign = 0.0f;
    label.set_ellipsize (Pango.EllipsizeMode.END);
    grid.attach (label, 1, 0, 1, 1);

    grid.set_row_spacing (18);

    var frame = new Frame (null);
    frame.get_style_context ().add_class ("contacts-avatar-frame");
    grid.attach (frame, 0, 1, 2, 1);
    frame_grid = new Grid ();
    frame_grid.set_orientation (Orientation.VERTICAL);
    frame.add (frame_grid);

    scrolled = new ScrolledWindow(null, null);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_size_request (-1, 300);

    frame_grid.add (scrolled);

    view_grid = new Grid ();
    scrolled.add_with_viewport (view_grid);

    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);
    frame_grid.add (toolbar);

    add_button = new ToolButton (null, null);
    add_button.set_icon_name ("list-add-symbolic");
    add_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    add_button.is_important = true;
    toolbar.add (add_button);
    add_button.clicked.connect (select_avatar_file_cb);

    crop_button = new ToolButton (null, null);
    crop_button.set_icon_name ("object-select-symbolic");
    crop_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    crop_button.is_important = true;
    toolbar.add (crop_button);

    cancel_button = new ToolButton (null, null);
    cancel_button.set_icon_name ("edit-undo-symbolic");
    cancel_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    cancel_button.is_important = true;
    toolbar.add (cancel_button);

    /*
    var remove_button = new ToolButton (null, null);
    remove_button.set_icon_name ("list-remove-symbolic");
    remove_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    remove_button.is_important = true;
    toolbar.add (remove_button);
    remove_button.clicked.connect ( (button) => {
		});
    */

    response.connect ( (response_id) => {
	if (response_id == ResponseType.CLOSE) {
	  if (new_pixbuf != null) {
	    var icon = new MemoryIcon.from_pixbuf (new_pixbuf);
	    set_avatar (icon);
	  }
	}
	this.destroy ();
      });

    update_grid ();

    grid.show_all ();

    crop_button.hide ();
    cancel_button.hide ();
  }
}
