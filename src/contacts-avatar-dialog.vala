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
  const int main_size = 128;
  const int icons_size = 64;
  const int n_columns = 6;
  private Contact contact;
  private Notebook notebook;
  private Um.CropArea crop_area;
  private Grid view_grid;
  private ContactFrame main_frame;

#if HAVE_CHEESE
  private Cheese.Flash flash;
  private Cheese.CameraDeviceMonitor camera_monitor;
  private Cheese.Widget cheese;
  private int num_cameras;
#endif

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
    var p = pixbuf.scale_simple (main_size, main_size, Gdk.InterpType.HYPER);
    main_frame.set_pixbuf (p);

    new_pixbuf = pixbuf;
  }

  private void update_grid () {
    int i = 0;
    int j = 0;

    foreach (var p in contact.individual.personas) {
      ContactFrame? frame = frame_for_persona (p);
      if (frame != null) {
	view_grid.attach (frame, i, j, 1, 1);
	i++;
	if (i >= n_columns) {
	  i -= n_columns;
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
      view_grid.attach (s, 0, j++, n_columns, 1);
    }

    var stock_files = Utils.get_stock_avatars ();
    foreach (var file_name in stock_files) {
      ContactFrame? frame = frame_for_filename (file_name);
      if (frame != null) {
	view_grid.attach (frame, i, j, 1, 1);
	i++;
	if (i >= n_columns) {
	  i -= n_columns;
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
	var file_info = file.query_info (FileAttribute.STANDARD_CONTENT_TYPE,
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

  private void set_crop_widget (Gdk.Pixbuf pixbuf) {
    var frame_grid = notebook.get_nth_page (1) as Grid;
    crop_area = new Um.CropArea ();
    crop_area.set_vexpand (true);
    crop_area.set_hexpand (true);
    crop_area.set_min_size (48, 48);
    crop_area.set_constrain_aspect (true);
    crop_area.set_picture (pixbuf);

    frame_grid.attach (crop_area, 0, 0, 1, 1);
    frame_grid.show_all ();

    notebook.set_current_page (1);
  }

  private void select_avatar_file_cb () {
    var chooser = new FileChooserDialog (_("Browse for more pictures"),
					 (Gtk.Window)this.get_toplevel (),
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
          set_crop_widget (pixbuf);
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
    grid.set_column_spacing (16);
    var container = (get_content_area () as Container);
    container.add (grid);

    main_frame = new ContactFrame (main_size);
    contact.keep_widget_uptodate (main_frame, (w) => {
	(w as ContactFrame).set_image (contact.individual, contact);
      });
    main_frame.set_hexpand (false);
    grid.attach (main_frame, 0, 0, 1, 1);

    var label = new Label ("");
    label.set_markup (Markup.printf_escaped ("<span font='16'>%s</span>", contact.display_name));
    label.set_valign (Align.START);
    label.set_halign (Align.START);
    label.set_hexpand (true);
    label.set_margin_top (4);
    label.xalign = 0.0f;
    label.set_ellipsize (Pango.EllipsizeMode.END);
    grid.attach (label, 1, 0, 1, 1);

    grid.set_row_spacing (11);

    var frame = new Frame (null);
    frame.get_style_context ().add_class ("contacts-avatar-frame");
    grid.attach (frame, 0, 1, 2, 1);

    notebook = new Gtk.Notebook ();
    notebook.show_tabs = false;
    frame.add (notebook);

    var frame_grid = new Grid ();
    frame_grid.set_orientation (Orientation.VERTICAL);

    /* main view */
    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_size_request (-1, 300);

    frame_grid.add (scrolled);

    view_grid = new Grid ();
    scrolled.add_with_viewport (view_grid);

    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_INLINE_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);
    frame_grid.add (toolbar);

    var the_add_button = new ToolButton (null, null);
    the_add_button.set_icon_name ("list-add-symbolic");
    the_add_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    the_add_button.is_important = true;
    toolbar.add (the_add_button);
    the_add_button.clicked.connect (select_avatar_file_cb);

#if HAVE_CHEESE
    var webcam_button = new ToolButton (null, null);
    webcam_button.set_icon_name ("camera-photo-symbolic");
    webcam_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    webcam_button.is_important = true;
    webcam_button.sensitive = false;
    toolbar.add (webcam_button);

    camera_monitor = new Cheese.CameraDeviceMonitor ();
    camera_monitor.added.connect ( () => {
	num_cameras++;
	webcam_button.sensitive = num_cameras > 0;
    });
    camera_monitor.removed.connect ( () => {
	num_cameras--;
	webcam_button.sensitive = num_cameras > 0;
    });
    camera_monitor.coldplug ();

    webcam_button.clicked.connect ( (button) => {
	notebook.set_current_page (2);
	cheese.show ();
      });
#endif

    frame_grid.show_all ();
    notebook.append_page (frame_grid, null);

    /* crop page */
    frame_grid = new Grid ();
    frame_grid.set_orientation (Orientation.VERTICAL);

    toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_INLINE_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);
    frame_grid.attach (toolbar, 0, 1, 1, 1);

    var accept_button = new ToolButton (null, null);
    accept_button.set_icon_name ("object-select-symbolic");
    accept_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    accept_button.is_important = true;
    toolbar.add (accept_button);
    accept_button.clicked.connect ( (button) => {
      var pix = crop_area.get_picture ();
      selected_pixbuf (scale_pixbuf_for_avatar_use (pix));
      crop_area.destroy ();
      notebook.set_current_page (0);
    });

    var cancel_button = new ToolButton (null, null);
    cancel_button.set_icon_name ("edit-undo-symbolic");
    cancel_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    cancel_button.is_important = true;
    toolbar.add (cancel_button);
    cancel_button.clicked.connect ( (button) => {
	crop_area.destroy ();
	notebook.set_current_page (0);
    });

    frame_grid.show_all ();
    notebook.append_page (frame_grid, null);

#if HAVE_CHEESE
    /* photobooth page */
    frame_grid = new Grid ();
    frame_grid.set_orientation (Orientation.VERTICAL);

    cheese = new Cheese.Widget ();
    cheese.set_vexpand (true);
    cheese.set_hexpand (true);
    cheese.set_no_show_all (true);
    frame_grid.add (cheese);

    flash = new Cheese.Flash ();

    toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);
    frame_grid.attach (toolbar, 0, 1, 1, 1);

    accept_button = new ToolButton (null, null);
    accept_button.set_icon_name ("object-select-symbolic");
    accept_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    accept_button.is_important = true;
    toolbar.add (accept_button);

    accept_button.clicked.connect ( (button) => {
	var camera = cheese.get_camera () as Cheese.Camera;

	var screen = button.get_screen ();
        Gdk.Rectangle rect = { 0, 0, screen.get_width (), screen.get_height ()};
        flash.fire (rect);

	camera.photo_taken.connect ( (pix) => {
	    set_crop_widget (pix);
	    cheese.hide ();
	  });

	if (!camera.take_photo_pixbuf ()) {
	    warning ("Unable to take photo");
	}
      });

    cancel_button = new ToolButton (null, null);
    cancel_button.set_icon_name ("edit-undo-symbolic");
    cancel_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    cancel_button.is_important = true;
    toolbar.add (cancel_button);
    cancel_button.clicked.connect ( (button) => {
        notebook.set_current_page (0);
	cheese.hide ();
    });

    frame_grid.show_all ();
    notebook.append_page (frame_grid, null);
#endif

    notebook.set_current_page (0);
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
	    try {
	      var icon = new MemoryIcon.from_pixbuf (new_pixbuf);
	      set_avatar (icon);
	    } catch {
	    }
	  }
	}

#if HAVE_CHEESE
	/* Ensure the Vala garbage collector disposes of the Cheese widget.
	 * This prevents the 'Device or resource busy' warnings, see:
	 *   https://bugzilla.gnome.org/show_bug.cgi?id=700959
	 */
	cheese = null;
#endif

	this.destroy ();
      });

    update_grid ();

    grid.show_all ();
  }
}
