/*
 * Copyright (C) 2018 Elias Entrup <elias-git@flump.de>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-crop-dialog.ui")]
public class Contacts.CropDialog : Adw.Dialog {

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

  public CropDialog.for_paintable (Gdk.Paintable paintable) {
    this.crop_area.set_paintable (paintable);
  }

  public CropDialog.for_portal (Xdp.Portal portal,
                                Gtk.Window? parent = null) {
    do_camera.begin(portal, parent, (obj, res) => {
      do_camera.end (res);
    });
  }

  private async void do_camera (Xdp.Portal portal, Gtk.Window? parent_window) {
    var parent = Xdp.parent_new_gtk (parent_window);
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
    var paintable_sink = Gst.ElementFactory.make ("gtk4paintablesink", null);
    if (source == null || queue == null || paintable_sink == null) {
      warning ("Your GStreamer installation is missing some required elements");
      return;
    }

    var paintable_value = GLib.Value (typeof (Gdk.Paintable));
    paintable_sink.get_property ("paintable", ref paintable_value);
    var paintable = paintable_value as Gdk.Paintable;

    // Check if GLContext is supported
    var gl_context_value = GLib.Value (typeof (Gdk.GLContext));
    paintable.get_property ("gl-context", ref gl_context_value);
    var gl_context = gl_context_value as Gdk.GLContext;

    bool is_gl_supported = gl_context != null;

    Gst.Element sink;
    if (is_gl_supported) {
      // Use glsinkbin if OpenGL is supported
      var glsinkbin = Gst.ElementFactory.make ("glsinkbin", null);
      if (glsinkbin == null) {
        warning ("Your GStreamer installation is missing the glsinkbin element");
        return;
      }
      glsinkbin.set_property ("sink", paintable_sink);
      sink = glsinkbin;
    } else {
      // Fallback to videoconvert if OpenGL is not supported
      var bin = new Gst.Bin (null);
      var convert = Gst.ElementFactory.make ("videoconvert", null);
      if (convert == null) {
        warning ("Your GStreamer installation is missing the videoconvert element");
        return;
      }

      bin.add_many (convert, paintable_sink);
      convert.link (paintable_sink);

      var ghost_pad = new Gst.GhostPad ("sink", convert.get_static_pad ("sink"));
      bin.add_pad (ghost_pad);

      sink = bin;
    }

    pipeline.add_many (source, queue, sink);
    source.link_many (queue, sink);

    this.crop_area.set_paintable (paintable);

    source.set_property ("fd", pw_fd);

    // Start
    pipeline.set_state (Gst.State.PLAYING);

    // Handle cleanup on window close
    this.closed.connect (() => {
      pipeline.set_state (Gst.State.NULL);
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
