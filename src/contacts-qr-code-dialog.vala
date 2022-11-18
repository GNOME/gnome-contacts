/*
 * Copyright (C) 2018 Elias Entrup <elias-git@flump.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Folks;
using GLib;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-qr-code-dialog.ui")]
public class Contacts.QrCodeDialog : Adw.PreferencesWindow {

  [GtkChild]
  private unowned Gtk.Picture qr_image;

  [GtkChild]
  private unowned Gtk.Label qr_subtitle;

  public QrCodeDialog.for_contact (Individual individual, Gtk.Window? parent = null) {
    Object (transient_for: parent);

    var subtitle = GLib.Markup.printf_escaped (_("Scan the QR code to save the contact <b>%s</b>."), individual.display_name);
    this.qr_subtitle.set_markup (subtitle);

    var individuals = new Gee.ArrayList<Individual> ();
    individuals.add (individual);

    var stringstream = new GLib.MemoryOutputStream.resizable ();
    var op = new Io.VCardExportOperation (individuals, stringstream);
    op.execute.begin ((obj, res) => {
      try {
        op.execute.end (res);
        uint8[] chars = {0};
        stringstream.write (chars);
        stringstream.close ();
      } catch (Error e) {
        warning ("ERROR: %s", e.message);
      }

      var content = (string) stringstream.steal_data ();
      int QR_IMAGE_SIZE = 300;
      var scale = this.qr_image.get_scale_factor ();
      create_qr_code (content, QR_IMAGE_SIZE * scale);
    });
  }

  private void create_qr_code (string content, int size) {
    if (content == "") {
      warning ("Failed to create QR code: no content");
      return;
    }

    var result = new QRencode.QRcode.encodeString (content,
                                                   0,
                                                   QRencode.EcLevel.M,
                                                   QRencode.Mode.B8, 1);
    if (result == null) {
      warning ("Failed to create QR code: libqrencode error");
      return;
    }

    var qr_size = result.width;
    var pixel_size = (int) double.max (1, size / qr_size);
    var total_size = qr_size * pixel_size;
    var BYTES_PER_R8G8B8 = 3;
    var qr_matrix = new GLib.ByteArray.sized ((uint)(total_size * total_size * pixel_size * BYTES_PER_R8G8B8));

    for (var column = 0; column < total_size; column++) {
      for (var i = 0; i < pixel_size; i++) {
        for (var row = 0; row < total_size / pixel_size; row++) {
          if ((result.data[qr_size*row + column] & 0x01) > 0) {
            fill_pixel (qr_matrix, 0x00, pixel_size);
          } else {
            fill_pixel (qr_matrix, 0xff, pixel_size);
          }
        }
      }
    }

    var bytes = ByteArray.free_to_bytes (qr_matrix);
    var paintable = new Gdk.MemoryTexture (total_size, total_size,
                                           Gdk.MemoryFormat.R8G8B8,
                                           bytes,
                                           total_size * BYTES_PER_R8G8B8);
    this.qr_image.set_paintable (paintable);
  }

  private void fill_pixel (GLib.ByteArray array, uint8 val, int pixel_size) {
    for (uint i = 0; i < pixel_size; i++) {
      array.append ({val}); /* R */
      array.append ({val}); /* G */
      array.append ({val}); /* B */
    }
  }
}

