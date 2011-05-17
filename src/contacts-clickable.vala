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

public class Contacts.Clickable : Bin  {
  const int ACTIVATE_TIMEOUT = 250;

  Gdk.Window event_window;
  bool in_button;
  bool button_down;
  bool focus_on_click;
  bool depressed;
  bool depress_on_activate;
  uint activate_timeout;
  uint32 grab_time;
  Gdk.Device grab_keyboard;

  public Clickable () {
    set_has_window (false);
    set_can_focus (true);
    focus_on_click = false;
    depress_on_activate = true;
    get_style_context ().add_class ("clickable");
  }

  [Signal (action=true, run="first")]
  public signal void clicked ();

  static construct {
    activate_signal = Signal.lookup ("activate", typeof (Clickable));
  }

  [Signal (action=true, run=true)]
  public new virtual signal void activate () {
    Gdk.Device device;
    uint32 time;

    device = Gtk.get_current_event_device ();

    if (device != null && device.get_source () != Gdk.InputSource.KEYBOARD)
      device = device.get_associated_device ();

  if (get_realized () && activate_timeout == 0)
    {
      time = Gtk.get_current_event_time ();

      if (device != null && device.get_source () == Gdk.InputSource.KEYBOARD)
	{
	  if (device.grab (event_window,
			   Gdk.GrabOwnership.WINDOW, true,
			   Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK,
			   null, time) == Gdk.GrabStatus.SUCCESS)
	    {
	      Gtk.device_grab_add (this, device, true);
	      grab_keyboard = device;
	      grab_time = time;
	    }
	}

      activate_timeout = Gdk.threads_add_timeout (ACTIVATE_TIMEOUT, () => {
	  finish_activate (true);
	  return false;
	});
      button_down = true;
      update_state ();
      queue_draw ();
    }
  }

  public override void realize () {
    Allocation allocation;

    get_allocation (out allocation);
    set_realized (true);

    unowned Gdk.Window window = get_parent_window ();
    set_window (window);

    var attrs = Gdk.WindowAttr () {
      window_type = Gdk.WindowType.CHILD,
      wclass = Gdk.WindowWindowClass.ONLY,
      event_mask = get_events ()
      | Gdk.EventMask.BUTTON_PRESS_MASK
      | Gdk.EventMask.BUTTON_RELEASE_MASK
      | Gdk.EventMask.ENTER_NOTIFY_MASK
      | Gdk.EventMask.LEAVE_NOTIFY_MASK,
      x = allocation.x,
      y = allocation.y,
      width = allocation.width,
      height = allocation.height
    };

    event_window = new Gdk.Window (get_parent_window (), attrs, Gdk.WindowAttributesType.X | Gdk.WindowAttributesType.Y);
    event_window.set_user_data (this);
  }

  public override void unrealize () {
    if (event_window != null) {
      event_window.set_user_data (null);
      event_window.destroy ();
      event_window = null;
    }
    base.unrealize ();
  }

  public override void map () {
    base.map ();
    if (event_window != null)
      event_window.show ();
  }

  public override void unmap () {
    if (event_window != null)
      event_window.hide ();
    base.unmap ();
  }

  public override void size_allocate (Allocation allocation) {
    var context = get_style_context ();
    set_allocation (allocation);

    if (get_realized ())
      event_window.move_resize (allocation.x,
				allocation.y,
				allocation.width,
				allocation.height);

    var child = get_child ();
    if (child != null) {
      Allocation child_allocation = Allocation();
      child_allocation.x = allocation.x;
      child_allocation.y = allocation.y;

      child_allocation.width = allocation.width;
      child_allocation.height = allocation.height;

      if (get_can_focus ()) {
	int focus_width, focus_pad;
	context.get_style ("focus-line-width", out focus_width,
			   "focus-padding", out focus_pad);

	child_allocation.x += focus_width + focus_pad;
	child_allocation.y += focus_width + focus_pad;
	child_allocation.width -= (focus_width + focus_pad) * 2;
	child_allocation.height -= (focus_width + focus_pad) * 2;
      }

      child.size_allocate (child_allocation);
    }
  }


  public override bool draw (Cairo.Context cr) {
    int x = 0;
    int y = 0;
    int width = get_allocated_width ();
    int height = get_allocated_height ();

    var context = get_style_context ();
    var state = get_state_flags ();

    context.save ();
    context.set_state (state);
    Gtk.render_background (context, cr, x, y, width, height);

    if (has_focus) {
      Gtk.render_focus (context, cr,
			x, y, width, height);
    }

    context.restore ();
    base.draw (cr);
    return false;
  }

  private void set_depressed (bool new_value) {
    if (new_value != depressed) {
      depressed = new_value;
      queue_resize ();
    }
  }

  private void update_state () {
    bool depressed;

    if (activate_timeout != 0)
      depressed = depress_on_activate;
    else
      depressed = in_button && button_down;

    var new_state = get_state_flags () & ~(StateFlags.PRELIGHT | StateFlags.ACTIVE);

    if (in_button)
      new_state |= StateFlags.PRELIGHT;

    if (button_down || depressed)
      new_state |= StateFlags.ACTIVE;

    set_depressed (depressed);
    set_state_flags (new_state, true);
  }

  private void button_pressed () {
    if (activate_timeout != 0)
      return;

    button_down = true;
    update_state ();
  }

  private void button_released () {
    if (button_down) {
      button_down = false;

      if (activate_timeout != 0)
	return;

      if (in_button)
	clicked ();

      update_state ();
    }
  }

  public override bool button_press_event (Gdk.EventButton event) {
    if (event.type == Gdk.EventType.BUTTON_PRESS) {
      if (focus_on_click && !has_focus)
	grab_focus ();

      if (event.button == 1)
	button_pressed ();
    }

    return true;
  }

  public override bool button_release_event (Gdk.EventButton event) {
    if (event.button == 1)
      button_released ();

    return true;
  }

  public override bool grab_broken_event (Gdk.EventGrabBroken event) {
    /* Simulate a button release without the pointer in the button */
    if (button_down) {
      var save_in = in_button;
      in_button = false;
      button_released ();
      if (save_in != in_button) {
	in_button = save_in;
	update_state ();
      }
    }

    return true;
  }

  public override bool enter_notify_event (Gdk.EventCrossing event) {
    if (event.window == event_window &&
	event.detail != Gdk.NotifyType.INFERIOR) {
      in_button = true;
      update_state ();
    }

    return false;
  }

  public override bool leave_notify_event (Gdk.EventCrossing event) {
    if (event.window == event_window &&
	event.detail != Gdk.NotifyType.INFERIOR &&
	get_sensitive ()) {
      in_button = false;
      update_state ();
    }

    return false;
  }

  private void finish_activate (bool do_it) {
    Source.remove (activate_timeout);
    activate_timeout = 0;

    if (grab_keyboard != null) {
      grab_keyboard.ungrab (grab_time);
      Gtk.device_grab_remove (this, grab_keyboard);
      grab_keyboard = null;
    }

    button_down = false;

    update_state ();
    queue_draw ();

    if (do_it)
      clicked();
  }

  public override void grab_notify (bool was_grabbed) {
    if (activate_timeout != 0 &&
	grab_keyboard != null &&
	device_is_shadowed (grab_keyboard))
      finish_activate (false);

    if (!was_grabbed) {
      var save_in = in_button;
      in_button = false;
      button_released ();
      if (save_in != in_button) {
	in_button = save_in;
	update_state ();
      }
    }
  }

  public override void state_changed (StateType previous_state) {
    if (!is_sensitive ()) {
      in_button = false;
      update_state ();
    }
  }

  public override void get_preferred_width (out int minimum_size, out int natural_size) {
    var context = get_style_context ();

    int minimum = 0;
    int natural = 0;

    if (get_can_focus ()) {
      int focus_width, focus_pad;
      context.get_style ("focus-line-width", out focus_width,
			 "focus-padding", out focus_pad);

      minimum += 2 * (focus_width + focus_pad);
      natural += 2 * (focus_width + focus_pad);
    }

    var child = get_child ();
    if (child != null && child.get_visible ()) {
      int child_min, child_nat;
      child.get_preferred_width (out child_min, out child_nat);

      minimum += child_min;
      natural += child_nat;
    }

    minimum_size = minimum;
    natural_size = natural;
  }

  public override void get_preferred_height (out int minimum_size, out int natural_size) {
    var context = get_style_context ();

    int minimum = 0;
    int natural = 0;

    if (get_can_focus ()) {
      int focus_width, focus_pad;
      context.get_style ("focus-line-width", out focus_width,
			 "focus-padding", out focus_pad);

      minimum += 2 * (focus_width + focus_pad);
      natural += 2 * (focus_width + focus_pad);
    }

    var child = get_child ();
    if (child != null && child.get_visible ()) {
      int child_min, child_nat;
      child.get_preferred_height (out child_min, out child_nat);

      minimum += child_min;
      natural += child_nat;
    }

    minimum_size = minimum;
    natural_size = natural;
  }
}
