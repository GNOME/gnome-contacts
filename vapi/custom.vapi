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

[CCode (cprefix = "Gtk", lower_case_cprefix = "gtk_", cheader_filename = "gtk/gtk.h")]
namespace Gtk {
	[CCode (cname = "gtk_builder_add_from_resource")]
	public static unowned uint my_builder_add_from_resource (Gtk.Builder builder, string path) throws GLib.Error;
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
		public Flash (Gtk.Widget parent);
		public void fire ();
	}
}
