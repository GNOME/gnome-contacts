/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
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

using Gtk;

public class Contacts.ContactRow : Grid {
  public Alignment left;
  public Grid content;
  public Alignment right;
  int start;

  public ContactRow (ContactPane pane) {
    this.set_orientation (Orientation.HORIZONTAL);
    this.set_column_spacing (8);

    this.set_hexpand (true);
    this.set_vexpand (false);

    left = new Alignment (1,0,0,0);
    left.set_hexpand (true);
    pane.border_size_group.add_widget (left);

    content = new Grid ();
    content.set_size_request (450, -1);

    right = new Alignment (0,0,0,0);
    right.set_hexpand (true);
    pane.border_size_group.add_widget (right);

    this.attach (left, 0, 0, 1, 1);
    this.attach (content, 1, 0, 1, 1);
    this.attach (right, 2, 0, 1, 1);
    this.show_all ();
  }

  public void pack_start (Widget w, Align align = Align.START) {
    content.attach (w, 0, start++, 1, 1);
    w.set_hexpand (true);
    w.set_halign (align);
  }

  public void pack_end (Widget w) {
    content.attach (w, 1, 0, 1, 1);
    w.set_hexpand (false);
    w.set_halign (Align.END);
  }

  public void label (string s) {
    var l = new Label (s);
    l.get_style_context ().add_class ("dim-label");
    pack_start (l);
  }

  public void text (string s, bool wrap = false) {
    var l = new Label (s);
    if (wrap) {
      l.set_line_wrap (true);
      l.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    } else {
      l.set_ellipsize (Pango.EllipsizeMode.END);
    }
    pack_start (l);
  }

  public void detail (string s) {
    var l = new Label (s);
    l.get_style_context ().add_class ("dim-label");
    pack_end (l);
  }
}

