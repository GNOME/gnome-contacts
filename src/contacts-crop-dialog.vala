/*
 * Copyright (C) 2018 Elias Entrup <elias-git@flump.de>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-crop-dialog.ui")]
public class Contacts.CropDialog : Adw.Window {

  [GtkChild]
  private unowned Cc.CropArea crop_area;

  public signal void cropped (Gdk.Texture texture);

  static construct {
    typeof (Cc.CropArea).ensure ();
    install_action ("crop", null, (Gtk.WidgetActionActivateFunc) on_crop);
  }

  construct {
    this.crop_area.set_min_size (48, 48);
  }

  public CropDialog.for_paintable (Gdk.Paintable paintable,
                                   Gtk.Window? parent = null) {
    Object (transient_for: parent);

    this.crop_area.set_paintable (paintable);
  }

  public CropDialog.for_portal (Xdp.Portal portal,
                                Gtk.Window? parent = null) {
    Object (transient_for: parent);

    do_camera.begin(portal, (obj, res) => {
      do_camera.end (res);
    });
  }

  private async void do_camera (Xdp.Portal portal) {
    var parent = Xdp.parent_new_gtk (this);
    try {
      debug ("Requesting camera access");
      yield portal.access_camera (parent, Xdp.CameraFlags.NONE, null);
      debug ("Camera access success");
    } catch (GLib.Error err) {
      warning ("Couldn't access camera: %s", err.message);
      return;
    }

    var pw_fd = portal.open_pipewire_remote_for_camera ();
    debug ("Got Pipewire fd %d", pw_fd);

    // Setup GStreamer pipeline
    var pipeline = new Gst.Pipeline (null);

    var source = Gst.ElementFactory.make ("pipewiresrc", null);
    var queue = Gst.ElementFactory.make ("queue", null);
    var glsinkbin = Gst.ElementFactory.make ("glsinkbin", null);
    var paintable_sink = Gst.ElementFactory.make ("gtk4paintablesink", null);
    if (source == null || queue == null || glsinkbin == null || paintable_sink == null) {
      warning ("Your GStreamer installation is missing some required elements");
      return;
    }

    pipeline.add_many (source, queue, glsinkbin);
    source.link_many (queue, glsinkbin);

    var paintable = GLib.Value (typeof (Gdk.Paintable));
    paintable_sink.get_property ("paintable", ref paintable);
    this.crop_area.set_paintable (paintable as Gdk.Paintable);
    glsinkbin.set_property ("sink", paintable_sink);

    source.set_property ("fd", pw_fd);

    // Start
    pipeline.set_state (Gst.State.PLAYING);

    // Handle cleanup on window close
    this.close_request.connect (() => {
      pipeline.set_state (Gst.State.NULL);
      return false;
    });

    // Watch the bus
    var bus = pipeline.get_bus ();
    bus.add_signal_watch ();
    bus.message.connect ((bus, message) => {
      if (message.type == Gst.MessageType.ERROR) {
        GLib.Error err;
        string debug;
        message.parse_error (out err, out debug);
        warning ("GStreamer error: %s. %s", err.message, debug);
      } else if (message.type == Gst.MessageType.EOS) {
        warning ("EOS");
      }
    });
  }

  private void on_crop (string action_name, Variant? param) {
    var texture = this.crop_area.create_texture ();
    close ();
    cropped (texture);
  }
}
