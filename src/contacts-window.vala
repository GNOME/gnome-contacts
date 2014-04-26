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
using Folks;

[GtkTemplate (ui = "/org/gnome/contacts/contacts-window.ui")]
public class Contacts.Window : Gtk.ApplicationWindow {
  [GtkChild]
  private HeaderBar left_toolbar;
  [GtkChild]
  private HeaderBar right_toolbar;
  [GtkChild]
  private Overlay overlay;
  [GtkChild]
  private Grid grid;
  [GtkChild]
  private Overlay right_overlay;

  [GtkChild]
  public Store contacts_store;

  /* FIXME: remove from public what it is not needed */
  [GtkChild]
  public Button add_button;
  [GtkChild]
  public ToggleButton select_button;

  [GtkChild]
  public Button edit_button;
  [GtkChild]
  public Button done_button;

  public string left_title {
    get {
      return left_toolbar.get_title ();
    }
    set {
      left_toolbar.set_title (value);
    }
  }

  public string right_title {
    get {
      return right_toolbar.get_title ();
    }
    set {
      right_toolbar.set_title (value);
    }
  }

  public Window (Gtk.Application app) {
    Object (application: app);

    string layout_desc;
    string[] tokens;

    layout_desc = Gtk.Settings.get_default ().gtk_decoration_layout;
    tokens = layout_desc.split (":", 2);
    if (tokens != null) {
      right_toolbar.decoration_layout = ":%s".printf (tokens[1]);
      left_toolbar.decoration_layout = tokens[0];
    }
  }

  public void activate_selection_mode (bool active) {
    if (active) {
      add_button.hide ();

      left_toolbar.get_style_context ().add_class ("selection-mode");
      right_toolbar.get_style_context ().add_class ("selection-mode");

      left_toolbar.set_title (_("Select"));
    } else {
      add_button.show ();

      left_toolbar.get_style_context ().remove_class ("selection-mode");
      right_toolbar.get_style_context ().remove_class ("selection-mode");

      left_toolbar.set_title (_("All Contacts"));
    }
  }

  public void add_left_child (Widget child) {
    grid.attach (child, 0, 0, 1, 1);

    /* horizontal size group, for the splitted headerbar */
    var hsize_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
    hsize_group.add_widget (left_toolbar);
    hsize_group.add_widget (child);
    child.show ();
  }

  public void add_right_child (Widget child) {
    right_overlay.add (child);
    child.show ();
  }

  public void add_notification (Widget notification) {
    overlay.add_overlay (notification);
  }
}
