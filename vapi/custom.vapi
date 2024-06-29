[CCode (cprefix = "Cc", lower_case_cprefix = "cc_", cheader_filename = "cc-crop-area.h")]
namespace Cc {
    public class CropArea : Gtk.Widget {
        [CCode (has_construct_function = false, type = "GtkWidget*")]
        public CropArea ();
        public void set_min_size (int width, int height);
        public void set_paintable (Gdk.Paintable paintable);
        public Gdk.Paintable get_paintable ();
        public Gdk.Texture create_texture ();
    }
}

