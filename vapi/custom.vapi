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
}
