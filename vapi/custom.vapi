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
	[CCode (cname = "contacts_eds_local_store")]
	public static string? eds_local_store;
	[CCode (cname = "contacts_lookup_esource_name_by_uid")]
	public static unowned string? lookup_esource_name_by_uid (string uid);
	[CCode (cname = "contacts_lookup_esource_name_by_uid_for_contact")]
	public static unowned string? lookup_esource_name_by_uid_for_contact (string uid);
	[CCode (cname = "contacts_esource_uid_is_google")]
	public static bool esource_uid_is_google (string uid);
	[CCode (cname = "eds_personal_google_group_name")]
	public static unowned string? eds_personal_google_group_name ();
	[CCode (cname = "contacts_has_goa_account")]
	public static bool has_goa_account ();
	[CCode (cname = "contacts_source_list")]
	public static E.SourceList eds_source_list;
	[CCode (cname = "contacts_avoid_goa_workaround")]
	public static bool avoid_goa_workaround;
}

[CCode (cprefix = "Gtk", lower_case_cprefix = "gtk_", cheader_filename = "gtk-notification.h")]
namespace Gtk {
	public class Notification : Gtk.Box {
		[CCode (has_construct_function = false, type = "GtkWidget*")]
		public Notification ();
		public void set_timeout (uint timeout_msec);
		public void dismiss ();
		public virtual signal void dismissed ();
	}
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
