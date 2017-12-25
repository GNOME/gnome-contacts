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
