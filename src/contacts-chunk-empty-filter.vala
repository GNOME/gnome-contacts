/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A custom GtkFilter to filter {@link Chunk}s on them possibly being non-empty.
 */
public class Contacts.ChunkEmptyFilter : Gtk.Filter {

  /** Whether empty chunks match the filter */
  public bool allow_empty {
    get { return this._allow_empty; }
    set {
      if (this._allow_empty == value)
        return;

      this._allow_empty = value;
      changed (value? Gtk.FilterChange.LESS_STRICT : Gtk.FilterChange.MORE_STRICT);
    }
  }
  private bool _allow_empty = false;

  public override bool match (GLib.Object? item) {
    unowned var chunk = (Chunk) item;
    return match_empty (chunk);
  }

  private bool match_empty (Chunk chunk) {
    return this.allow_empty || !chunk.is_empty;
  }

  public override Gtk.FilterMatch get_strictness () {
    return this.allow_empty? Gtk.FilterMatch.ALL : Gtk.FilterMatch.SOME;
  }
}
