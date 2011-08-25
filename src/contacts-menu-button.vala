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

public class Contacts.MenuButton : ToggleButton  {
  Menu? menu;
  bool popup_in_progress;

  public MenuButton (string label) {
    set_focus_on_click (false);

    var label_widget = new Label (label);
    var arrow = new Arrow (ArrowType.DOWN, ShadowType.NONE);
    var grid = new Grid ();
    grid.set_orientation (Orientation.HORIZONTAL);
    grid.add (label_widget);
    grid.add (arrow);
    grid.set_row_spacing (3);
    grid.set_hexpand (true);
    grid.set_halign (Align.CENTER);
    this.add (grid);
  }

  ~MenuButton () {
    set_menu (null);
  }

  private void menu_position (Menu menu, out int x, out int y, out bool push_in) {
    Allocation allocation;
    get_allocation (out allocation);

    int sx = 0;
    int sy = 0;

    if (!get_has_window ()) {
      sx += allocation.x;
      sy += allocation.y;
    }

    get_window ().get_root_coords (sx, sy, out sx, out sy);

    Requisition menu_req;
    Gdk.Rectangle monitor;

    menu.get_preferred_size (null, out menu_req);

    if (get_direction () == TextDirection.LTR)
      x = sx;
    else
      x = sx + allocation.width - menu_req.width;
    y = sy;

    var window = get_window ();
    var screen = get_screen ();
    var monitor_num = screen.get_monitor_at_window (window);
    if (monitor_num < 0)
      monitor_num = 0;
    screen.get_monitor_geometry (monitor_num, out monitor);

    if (x < monitor.x)
      x = monitor.x;
    else if (x + menu_req.width > monitor.x + monitor.width)
      x = monitor.x + monitor.width - menu_req.width;

    if (monitor.y + monitor.height - y - allocation.height >= menu_req.height)
      y += allocation.height;
    else if (y - monitor.y >= menu_req.height)
      y -= menu_req.height;
    else if (monitor.y + monitor.height - y - allocation.height > y - monitor.y)
      y += allocation.height;
    else
      y -= menu_req.height;

    menu.set_monitor (monitor_num);

    Window? toplevel = menu.get_parent() as Window;
    if (toplevel != null && !toplevel.get_visible())
      toplevel.set_type_hint (Gdk.WindowTypeHint.DROPDOWN_MENU);

    push_in = false;
  }

  public override void toggled () {
    var context = get_style_context ();
    if (get_active ()) {
      if (!popup_in_progress)
	menu.popup (null, null, menu_position, 1, Gtk.get_current_event_time ());
      context.add_class (STYLE_CLASS_MENUBAR);
      context.add_class (STYLE_CLASS_MENUITEM);
    } else {
      context.remove_class (STYLE_CLASS_MENUBAR);
      context.remove_class (STYLE_CLASS_MENUITEM);
      menu.popdown ();
    }
    reset_style ();
  }

  public override bool button_press_event (Gdk.EventButton event) {
    var ewidget = Gtk.get_event_widget ((Gdk.Event)(&event));

    if (ewidget != this ||
	get_active ())
      return false;

    menu.popup (null, null, menu_position, 1, Gtk.get_current_event_time ());
    set_active (true);
    popup_in_progress = true;
    return true;
  }

  public override bool button_release_event (Gdk.EventButton event) {
    bool popup_in_progress_saved = popup_in_progress;
    popup_in_progress = false;

    var ewidget = Gtk.get_event_widget ((Gdk.Event)(&event));

    if (ewidget == this &&
	!popup_in_progress_saved &&
	get_active ()) {
      menu.popdown ();
      return true;
    }
    if (ewidget != this)    {
      menu.popdown ();
      return true;
    }
    return false;
  }

  private void menu_show (Widget menu) {
    popup_in_progress = true;
    set_active (true);
    popup_in_progress = false;
  }

  private void menu_hide (Widget menu) {
    set_active (false);
  }

  private void menu_detach (Menu menu) {
  }

  public void set_menu (Menu? menu) {
    if (this.menu != null) {
      this.menu.show.disconnect (menu_show);
      this.menu.hide.disconnect (menu_hide);
      this.menu.detach ();
    }

    this.menu = menu;

    if (this.menu != null) {
      this.menu.show.connect (menu_show);
      this.menu.hide.connect (menu_hide);
      this.menu.attach_to_widget (this, menu_detach);
    }
  }

  public override bool draw (Cairo.Context cr) {
    base.draw (cr);
    return false;
  }

}
