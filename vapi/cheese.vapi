[CCode (cprefix = "Cheese", lower_case_cprefix = "cheese_", cheader_filename = "cheese/cheese-gtk.h")]
namespace Cheese {
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
	[CCode (cheader_filename = "cheese-widget.h")]
	public class Widget : Gtk.Widget {
		[CCode (has_construct_function = false, type = "CheeseWidget*")]
		public Widget ();
		public WidgetState state { get; }
		public unowned GLib.Object get_camera ();
		public unowned Gtk.Widget get_video_area ();
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
