[CCode (cheader_filename = "goabackend/goabackend.h")]
namespace Goa {
  public class Provider : GLib.Object {
    // FIXME: we would ofc like this to be an async method, but it seems that _finish is not helping us
    // by not having AsyncResult as its first argument
    public static void get_all (GLib.AsyncReadyCallback cb);
    public static bool get_all_finish (out GLib.List<Provider> providers, GLib.AsyncResult res) throws GLib.Error;

    public string get_provider_name (Goa.Object? object = null);
    public GLib.Icon get_provider_icon (Goa.Object? object = null);
    public unowned string get_provider_type ();
    public ProviderFeatures get_provider_features ();

    public void add_account (Goa.Client client, Gtk.Dialog dialog, Gtk.Box vbox) throws GLib.Error;
  }

  [Flags]
  [CCode (cprefix = "GOA_PROVIDER_FEATURE_")]
  public enum ProviderFeatures {
    BRANDED,
    MAIL,
    CALENDAR,
    CONTACTS,
    CHAT,
    DOCUMENTS,
    PHOTOS,
    FILES,
    TICKETING,
    READ_LATER,
    PRINTERS,
    MAPS,
    MUSIC,
    TODO,
    INVALID;
  }
}
