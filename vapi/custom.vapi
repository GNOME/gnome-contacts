[CCode (cprefix = "Contacts", lower_case_cprefix = "contacts_", cheader_filename = "contacts-esd-setup.h")]
namespace Contacts {
	[CCode (cname = "contacts_ensure_eds_accounts")]
	public static bool ensure_eds_accounts (bool allow_interaction);
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
	[CCode (cname = "contacts_get_icon_for_goa_account")]
	public static unowned Gtk.Widget get_icon_for_goa_account (string goa_id);
}

[CCode (cprefix = "Cc", lower_case_cprefix = "cc_", cheader_filename = "cc-crop-area.h")]
namespace Cc {
	public class CropArea : Gtk.DrawingArea {
		[CCode (has_construct_function = false, type = "GtkWidget*")]
		public CropArea ();
		public void set_min_size (int width, int height);
		public void set_constrain_aspect (bool  constrain);
		public void set_picture (Gdk.Pixbuf pixbuf);
		public Gdk.Pixbuf get_picture ();
	}
}
