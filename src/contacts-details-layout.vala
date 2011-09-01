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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

using Gtk;
using Folks;
using Gee;

class Contacts.DetailsLayout : Object {
  public class SharedState {
    public SizeGroup label_size_group;
    public SharedState () {
      label_size_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
    }
  }

  public DetailsLayout (SharedState s) {
    shared_state = s;
    grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_column_spacing (3);
  }

  SharedState shared_state;
  public Grid grid;

  private bool expands;
  public Grid? current_row;
  Widget? last_label;
  Box? detail_box;

  public void reset () {
    foreach (var w in grid.get_children ()) {
      w.destroy ();
    }
    current_row = null;
    last_label = null;
    detail_box = null;
  }

  void new_row () {
    var row = new Grid ();
    expands = false;
    last_label = null;
    row.set_row_spacing (9);
    row.set_column_spacing (3);
    row.set_orientation (Orientation.HORIZONTAL);
    current_row = row;
    grid.add (row);
  }

  public void add_widget_label (Widget w) {
    new_row ();

    shared_state.label_size_group.add_widget (w);
    current_row.add (w);
  }

  public void add_label (string label) {
    var l = new Label (label);
    l.set_markup ("<b>" + label + "</b>");
    l.get_style_context ().add_class ("dim-label");
    l.set_alignment (1, 0.5f);

    add_widget_label (l);
  }

  public void begin_detail_box () {
    var box = new Box (Orientation.VERTICAL, 0);
    attach_detail (box);
    detail_box = box;
  }

  public void end_detail_box () {
    detail_box = null;
  }

  public void attach_detail (Widget widget) {
    if (detail_box != null)
      detail_box.add (widget);
    else if (last_label != null)
      current_row.attach_next_to (widget, last_label, PositionType.BOTTOM, 1, 1);
    else
      current_row.add (widget);

    widget.show ();
    last_label = widget;
  }

  public void add_detail (string val) {
    var label = new Label (val);
    label.set_selectable (true);
    label.set_valign (Align.CENTER);
    label.set_halign (Align.START);
    label.set_ellipsize (Pango.EllipsizeMode.END);
    label.xalign = 0.0f;

    attach_detail (label);
  }

  public Entry add_entry (string val) {
    var entry = new Entry ();
    entry.get_style_context ().add_class ("contact-entry");
    entry.set_text (val);
    entry.set_valign (Align.CENTER);
    entry.set_halign (Align.FILL);
    entry.set_hexpand (true);
    expands = true;

    attach_detail (entry);
    return entry;
  }

  public void add_label_detail (string label, string val) {
    add_label (label);
    add_detail (val);
  }

  public void add_link (string uri, string text) {
    var v = new LinkButton.with_label (uri, text);
    v.set_valign (Align.CENTER);
    v.set_halign (Align.START);
    Label l = v.get_child () as Label;
    l.set_ellipsize (Pango.EllipsizeMode.END);
    l.xalign = 0.0f;


    attach_detail (v);
  }

  public Button add_button (string? icon, bool at_top = true) {
    var button = new Button ();
    button.set_valign (Align.CENTER);
    button.set_halign (Align.END);
    if (!expands)
      button.set_hexpand (true);

    if (icon != null) {
      var image = new Image();
      image.set_from_icon_name (icon, IconSize.MENU);
      button.add (image);
      image.show ();
    }

    if (at_top || last_label == null)
      current_row.add (button);
    else
      current_row.attach_next_to (button, last_label, PositionType.RIGHT, 1, 1);

    return button;
  }

  public Button add_remove (bool at_top = true) {
    var button = add_button ("edit-delete-symbolic", at_top);
    button.set_relief (ReliefStyle.NONE);
    return button;
  }
}
