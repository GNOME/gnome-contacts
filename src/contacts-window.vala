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

public class Contacts.Window : Gtk.ApplicationWindow {
  private HeaderBar left_toolbar;
  private HeaderBar right_toolbar;
  private Overlay overlay;
  private Grid grid;

  /* FIXME: remove from public what it is not needed */
  public Button add_button;
  public Gd.HeaderToggleButton select_button;

  public Button edit_button;
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

    set_default_size (800, 600);

    /* building ui, latter replaced by .ui resource file */
    /* titlebar */
    var titlebar = new Box (Orientation.HORIZONTAL, 0);
    left_toolbar = new HeaderBar ();
    left_toolbar.get_style_context ().add_class ("contacts-left-header-bar");
    titlebar.add (left_toolbar);

    /* FIXME: Here it should not be 'All' but the source of the contacts subset your
     viewing, if it happens to be 'All', well */
    left_toolbar.set_title (_("All Contacts"));

    var add_image = new Gtk.Image.from_icon_name ("list-add-symbolic", IconSize.MENU);
    add_button = new Button ();
    add_button.add (add_image);
    left_toolbar.pack_start (add_button);

    var select_image = new Gtk.Image.from_icon_name ("object-select-symbolic", IconSize.MENU);
    select_button = new Gd.HeaderToggleButton ();
    select_button.add (select_image);
    left_toolbar.pack_end (select_button);

    right_toolbar = new HeaderBar ();
    right_toolbar.set ("show-close-button", true);
    titlebar.pack_end (right_toolbar, true, true, 0);

    edit_button = new Button.with_label (_("Edit"));
    edit_button.set_size_request (70, -1);
    right_toolbar.pack_end (edit_button);

    done_button = new Button.with_label (_("Done"));
    done_button.set_size_request (70, -1);
    done_button.get_style_context ().add_class ("suggested-action");
    right_toolbar.pack_end (done_button);

    titlebar.show_all ();
    set_titlebar (titlebar);

    overlay = new Gtk.Overlay ();
    Gdk.RGBA transparent = { 0, 0, 0, 0 };
    overlay.override_background_color (0, transparent);

    add (overlay);

    grid = new Grid();
    overlay.add (grid);
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
    grid.attach (child, 0, 1, 1, 1);

    /* horizontal size group, for the splitted headerbar */
    var hsize_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
    hsize_group.add_widget (left_toolbar);
    hsize_group.add_widget (child);
  }

  public void add_right_child (Widget child) {
    Gdk.RGBA transparent = { 0, 0, 0, 0 };
    var right_overlay = new Overlay ();
    right_overlay.override_background_color (0, transparent);
    right_overlay.add (child);

    grid.attach (right_overlay, 1, 1, 1, 1);
  }

  public void add_notification (Widget notification) {
    overlay.add_overlay (notification);
  }
}
