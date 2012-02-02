/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
/*
 * Copyright (C) 2011 Philip Withnall
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *       Philip Withnall <philip@tecnocode.co.uk>
 */

using GLib;

/**
 * A wrapper around a blob of image data (with an associated content type) which
 * presents it as a {@link GLib.LoadableIcon}. This allows inlined avatars to be
 * returned as {@link GLib.LoadableIcon}s.
 */
internal class Contacts.MemoryIcon : Object, Icon, LoadableIcon {
  private uint8[] _image_data;
  private string? _image_type;

  public MemoryIcon (string? image_type, uint8[] image_data) {
    this._image_data = image_data;
    this._image_type = image_type;
  }

  public MemoryIcon.from_pixbuf (Gdk.Pixbuf pixbuf) throws GLib.Error {
    uint8[] buffer;
    if (pixbuf.save_to_buffer (out buffer, "png", null)) {
      this ("image/png", buffer);
    }
  }

#if VALA_0_16
  public bool equal (Icon? icon2)
#else
  public bool equal (Icon icon2)
#endif
  {
    /* These type and nullability checks are taken care of by the interface
     * wrapper. */
    var icon = (MemoryIcon) (!) icon2;
    return (this._image_data.length == icon._image_data.length &&
	    Memory.cmp (this._image_data, icon._image_data,
			this._image_data.length) == 0);
  }

  public uint hash () {
    /* Implementation based on g_str_hash() from GLib. We initialise the hash
     * with the g_str_hash() hash of the image type (which itself is
     * initialised with the magic number in GLib thought up by cleverer people
     * than myself), then add each byte in the image data to the hash value
     * by multiplying the hash value by 33 and adding the image data, as is
     * done on all bytes in g_str_hash(). I leave the rationale for this
     * calculation to the author of g_str_hash().
     *
     * Basically, this is just a nul-safe version of g_str_hash(). Which is
     * calculated over both the image type and image data. */
    uint hash = this._image_type != null ? ((!) this._image_type).hash () : 0;
    for (uint i = 0; i < this._image_data.length; i++) {
      hash = (hash << 5) + hash + this._image_data[i];
    }

    return hash;
  }

  public InputStream load (int size, out string? type,
			   Cancellable? cancellable = null) {
    type = this._image_type;
    return new MemoryInputStream.from_data (this._image_data, free);
  }

  public async InputStream load_async (int size, GLib.Cancellable? cancellable, out string? type) {
    type = this._image_type;
    return new MemoryInputStream.from_data (this._image_data, free);
  }
}
