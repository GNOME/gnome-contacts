[CCode (cprefix = "Cheese", lower_case_cprefix = "cheese_", cheader_filename = "cheese/cheese-gtk.h")]
namespace GtkCheese {
	[CCode (cheader_filename = "cheese/cheese-camera-device.h", cname = "cheese_gtk_init")]
	public static void init ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
}
