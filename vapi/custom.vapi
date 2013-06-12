namespace Gnome {
	[CCode (cheader_filename = "libgnome-desktop/gnome-desktop-thumbnail.h")]
	public class DesktopThumbnailFactory : GLib.Object {
		[CCode (has_construct_function = false)]
		public DesktopThumbnailFactory (Gnome.ThumbnailSize size);
		public bool can_thumbnail (string uri, string mime_type, ulong mtime);
		public void create_failed_thumbnail (string uri, ulong mtime);
		public unowned Gdk.Pixbuf generate_thumbnail (string uri, string mime_type);
		public bool has_valid_failed_thumbnail (string uri, ulong mtime);
		public unowned string lookup (string uri, ulong mtime);
		public void save_thumbnail (Gdk.Pixbuf thumbnail, string uri, ulong original_mtime);
	}
	[CCode (cheader_filename = "libgnome-desktop/gnome-desktop-thumbnail.h", cprefix = "GNOME_DESKTOP_THUMBNAIL_SIZE_")]
	public enum ThumbnailSize {
		NORMAL,
		LARGE
	}
}

[CCode (cprefix = "G", lower_case_cprefix = "g_", cheader_filename = "glib.h", gir_namespace = "GLib", gir_version = "2.0")]
namespace LocalGLib {
	[CCode (cname = "g_unichar_fully_decompose", cheader_filename = "glib.h")]
	public static unowned size_t fully_decompose (unichar ch, bool compat, unichar[] result);
}

[CCode (cprefix = "Contacts", lower_case_cprefix = "contacts_", cheader_filename = "contacts-esd-setup.h")]
namespace Contacts {
	[CCode (cname = "contacts_ensure_eds_accounts")]
	public static void ensure_eds_accounts ();
	[CCode (cname = "contacts_lookup_esource_name_by_uid")]
	public static unowned string? lookup_esource_name_by_uid (string uid);
	[CCode (cname = "contacts_lookup_esource_name_by_uid_for_contact")]
	public static unowned string? lookup_esource_name_by_uid_for_contact (string uid);
	[CCode (cname = "contacts_esource_uid_is_google")]
	public static bool esource_uid_is_google (string uid);
	[CCode (cname = "contacts_has_goa_account")]
	public static bool has_goa_account ();
	[CCode (cname = "eds_source_registry")]
	public static E.SourceRegistry eds_source_registry;
}

[CCode (cprefix = "Um", lower_case_cprefix = "um_", cheader_filename = "um-crop-area.h")]
namespace Um {
	public class CropArea : Gtk.DrawingArea {
		[CCode (has_construct_function = false, type = "GtkWidget*")]
		public CropArea ();
		public void set_min_size (int width, int height);
		public void set_constrain_aspect (bool  constrain);
		public void set_picture (Gdk.Pixbuf pixbuf);
		public Gdk.Pixbuf get_picture ();
	}
}

[CCode (cprefix = "Cheese", lower_case_cprefix = "cheese_", cheader_filename = "cheese/cheese-gtk.h")]
namespace Cheese {
	public static void gtk_init ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
	[CCode (cheader_filename = "cheese/cheese-camera-device.h")]
	public class CameraDevice : GLib.Object {
		[CCode (has_construct_function = false, type = "CheeseCameraDevice*")]
		public CameraDevice (string uuid, string device_node, string name, uint v4l_api_version) throws GLib.Error;
	}
	[CCode (cheader_filename = "cheese/cheese-camera-device-monitor.h")]
	public class CameraDeviceMonitor : GLib.Object {
		[CCode (has_construct_function = false, type = "CheeseCameraDeviceMonitor*")]
		public CameraDeviceMonitor ();
		public void coldplug ();
		public signal void added (CameraDevice device);
		public signal void removed (string uuid);
	}
	[CCode (cheader_filename = "cheese/cheese-avatar-chooser.h")]
	public class AvatarChooser : Gtk.Dialog {
		[CCode (has_construct_function = false, type = "CheeseAvatarChooser*")]
		public AvatarChooser ();
		public Gdk.Pixbuf get_picture ();
	}
	public enum WidgetState {
		NONE,
		READY,
		ERROR
	}
	[CCode (cheader_filename = "cheese/cheese-widget.h")]
	public class Widget : Gtk.Widget {
		[CCode (has_construct_function = false, type = "CheeseWidget*")]
		public Widget ();
		public WidgetState state { get; }
        public unowned GLib.Object get_camera ();
	}
	[CCode (cheader_filename = "cheese/cheese-camera.h")]
	public class Camera : GLib.Object {
		public bool take_photo_pixbuf ();
		public signal void photo_taken (Gdk.Pixbuf pixbuf);
	}
	[CCode (cheader_filename = "cheese-flash.h")]
	public class Flash : Gtk.Window {
		[CCode (has_construct_function = false, type = "CheeseFlash*")]
		public Flash ();
		public void fire (Gdk.Rectangle rect);
	}
}

[CCode (cprefix = "Gtk", gir_namespace = "Gtk", gir_version = "3.0", lower_case_cprefix = "gtk_")]
namespace LocalGtk {
	[CCode (cheader_filename = "gtk/gtk.h", type_id = "gtk_list_box_get_type ()")]
	public class ListBox : Gtk.Container, Atk.Implementor, Gtk.Buildable {
		[CCode (has_construct_function = false, type = "GtkWidget*")]
		public ListBox ();
		public void drag_highlight_row (LocalGtk.ListBoxRow row);
		public void drag_unhighlight_row ();
		public unowned Gtk.Adjustment get_adjustment ();
		public unowned LocalGtk.ListBoxRow get_row_at_index (int index);
		public unowned LocalGtk.ListBoxRow get_row_at_y (int y);
		public unowned LocalGtk.ListBoxRow get_selected_row ();
		public Gtk.SelectionMode get_selection_mode ();
		public void invalidate_filter ();
		public void invalidate_headers ();
		public void invalidate_sort ();
		public void select_row (LocalGtk.ListBoxRow? row);
		public void set_activate_on_single_click (bool single);
		public void set_adjustment (Gtk.Adjustment? adjustment);
		public void set_filter_func (owned LocalGtk.ListBoxFilterFunc? filter_func);
		public void set_header_func (owned LocalGtk.ListBoxUpdateHeaderFunc? update_header);
		public void set_placeholder (Gtk.Widget? placeholder);
		public void set_selection_mode (Gtk.SelectionMode mode);
		public void set_sort_func (owned LocalGtk.ListBoxSortFunc? sort_func);
		public bool activate_on_single_click { get; set; }
		public Gtk.SelectionMode selection_mode { get; set; }
		public virtual signal void activate_cursor_row ();
		public virtual signal void move_cursor (Gtk.MovementStep step, int count);
		public virtual signal void row_activated (LocalGtk.ListBoxRow row);
		public virtual signal void row_selected (LocalGtk.ListBoxRow row);
		public virtual signal void toggle_cursor_row ();
	}
	[CCode (cheader_filename = "gtk/gtk.h", type_id = "gtk_list_box_row_get_type ()")]
	public class ListBoxRow : Gtk.Bin, Atk.Implementor, Gtk.Buildable {
		[CCode (has_construct_function = false, type = "GtkWidget*")]
		public ListBoxRow ();
		public void changed ();
		public unowned Gtk.Widget get_header ();
		public void set_header (Gtk.Widget? header);
	}
	[CCode (cheader_filename = "gtk/gtk.h", instance_pos = 1.9)]
	public delegate bool ListBoxFilterFunc (LocalGtk.ListBoxRow row);
	[CCode (cheader_filename = "gtk/gtk.h", instance_pos = 2.9)]
	public delegate int ListBoxSortFunc (LocalGtk.ListBoxRow row1, LocalGtk.ListBoxRow row2);
	[CCode (cheader_filename = "gtk/gtk.h", instance_pos = 2.9)]
	public delegate void ListBoxUpdateHeaderFunc (LocalGtk.ListBoxRow row, LocalGtk.ListBoxRow before);
}
