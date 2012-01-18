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

public class Contacts.Clickable : Object {
  Widget widget;

  public StateFlags state;

  bool in_button;
  bool button_down;
  bool depressed;
  bool depress_on_activate;
  bool focus_on_click;
  uint activate_timeout;
  uint32  grab_time;
  Gdk.Device grab_keyboard;

  Gdk.Window? event_window;

  public Clickable (Widget w) {
    widget = w;

    widget.button_press_event.connect (button_press_event);
    widget.button_release_event.connect (button_release_event);
    widget.enter_notify_event.connect (enter_notify_event);
    widget.leave_notify_event.connect (leave_notify_event);
    widget.grab_broken_event.connect (grab_broken_event);
    widget.state_changed.connect (state_changed);
    widget.grab_notify.connect (grab_notify);

    widget.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK |
		       Gdk.EventMask.LEAVE_NOTIFY_MASK |
		       Gdk.EventMask.BUTTON_PRESS_MASK |
		       Gdk.EventMask.BUTTON_RELEASE_MASK);
  }

  public void set_focus_on_click (bool focus_on_click) {
    this.focus_on_click = focus_on_click;
  }

  public void realize_for (Gdk.Window? event_window) {
    this.event_window = event_window;
  }

  public void unrealize () {
    if (activate_timeout != 0)
      finish_activate (false);
  }

  private Gdk.Window get_event_window () {
    return this.event_window ?? widget.get_window ();
  }

  private void set_depressed (bool depressed) {
    if (depressed != this.depressed) {
      this.depressed = depressed;
      widget.queue_resize ();
    }
  }

  private bool button_press_event (Gdk.EventButton event) {
    if (event.button == 1) {
      if (focus_on_click && !widget.has_focus)
	widget.grab_focus ();

      pressed ();

      return true;
    }

    return false;
  }

  private bool button_release_event (Gdk.EventButton event) {
    if (event.button == 1) {
      released ();
      return true;
    }

    return false;
  }

  private bool grab_broken_event (Gdk.EventGrabBroken event) {

    /* Simulate a button release without the pointer in the button */
    if (button_down) {
      var save_in = in_button;
      in_button = false;
      released ();
      if (save_in != in_button)
	{
	  in_button = save_in;
	  update_state ();
	}
    }

    return true;
  }

  /* TODO: key_release_event */

  private bool enter_notify_event (Gdk.EventCrossing event) {
    if ((event.window == get_event_window ()) &&
	(event.detail != Gdk.NotifyType.INFERIOR)) {
      in_button = true;
      update_state ();

    }

    return false;
  }

  private bool leave_notify_event (Gdk.EventCrossing event) {
    if ((event.window == get_event_window ()) &&
	(event.detail != Gdk.NotifyType.INFERIOR) &&
	widget.get_sensitive ()) {
      in_button = false;
      update_state ();
    }

    return false;
  }

  private void pressed () {
    if (activate_timeout != 0)
      return;

    button_down = true;
    update_state ();
  }

  private void released () {
    if (button_down) {
      button_down = false;

      if (activate_timeout != 0)
	return;

      if (in_button)
	clicked ();
    }
    update_state ();
  }

  [CCode (action_signal = true)]
  public signal void clicked ();

  [CCode (action_signal = true)]
  public virtual signal void activate () {
    var device = Gtk.get_current_event_device ();

    if (device != null && device.get_source () != Gdk.InputSource.KEYBOARD)
      device = device.get_associated_device ();

  if (widget.get_realized () && activate_timeout == 0)
    {
      var time = Gtk.get_current_event_time ();

      /* bgo#626336 - Only grab if we have a device (from an event), not if we
       * were activated programmatically when no event is available.
       */
      if (device != null && device.get_source () == Gdk.InputSource.KEYBOARD)
	{
	  if (device.grab (get_event_window (),
			   Gdk.GrabOwnership.WINDOW, true,
			   Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK,
			   null, time) == Gdk.GrabStatus.SUCCESS)
	    {
	      Gtk.device_grab_add (widget, device, true);
	      grab_keyboard = device;
	      grab_time = time;
	    }
	}

      activate_timeout = Gdk.threads_add_timeout (250,
						  activate_timeout_cb);
      button_down = true;
      update_state ();
      widget.queue_draw ();
    }
  }

  private void finish_activate (bool do_it) {
    Source.remove (activate_timeout);
    activate_timeout = 0;

    if (grab_keyboard != null) {
      grab_keyboard.ungrab (grab_time);
      Gtk.device_grab_remove (widget, grab_keyboard);
      grab_keyboard = null;
    }

    button_down = false;

    update_state ();
    widget.queue_draw ();

    if (do_it)
      clicked ();
  }

  private  bool activate_timeout_cb () {
    finish_activate (true);

    return false;
  }

  private void update_state () {
    bool depressed;

    if (activate_timeout != 0)
      depressed = depress_on_activate;
    else
      depressed = in_button && button_down;

    StateFlags new_state = 0;

    if (in_button)
      new_state |= StateFlags.PRELIGHT;

    if (button_down || depressed)
      new_state |= StateFlags.ACTIVE;

    if (new_state != state) {
      state = new_state;
      widget.queue_resize ();
    }

    set_depressed (depressed);
  }

  private void state_changed (Gtk.StateType previous_state) {
    if (!widget.is_sensitive ()) {
      in_button = false;
      released ();
    }
  }

  private void grab_notify (bool was_grabbed) {
    if (activate_timeout != 0 &&
	grab_keyboard != null &&
	widget.device_is_shadowed (grab_keyboard))
      finish_activate (false);

    if (!was_grabbed) {
      bool save_in = in_button;
      in_button = false;
      released ();
      if (save_in != in_button)
	{
	  in_button = save_in;
	  update_state ();
	}
    }
  }
}
