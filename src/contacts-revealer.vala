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

private double transition_ease_out_quad (double t,
					 double d) {
  double p = t / d;
  return -1.0 * p * (p - 2);
}

public class Contacts.Revealer : Bin {
  public Gtk.Orientation orientation { get; set; default = Gtk.Orientation.HORIZONTAL; }
  public int duration { get; set; default = 250;}

  private Gdk.Window? bin_window;
  private Gdk.Window? view_window;

  private double current_pos;
  private double source_pos;
  private double target_pos;

  private const int frame_time = 17; /* 17 msec ~= 60fps */
  private uint timeout;
  private int64 start_time;
  private int64 end_time;

  public Revealer () {
    target_pos = current_pos = 0.0;
    set_has_window (true);
    set_redraw_on_allocate (false);
  }

  private void get_child_allocation (Gtk.Allocation allocation, out Gtk.Allocation child_allocation) {
    child_allocation = { 0, 0, allocation.width, allocation.height };

    var child = get_child ();
    if (child != null && child.get_visible ()) {
	if (orientation == Gtk.Orientation.HORIZONTAL)
	  child.get_preferred_height_for_width (child_allocation.width, null,
						out child_allocation.height);
	else
	  child.get_preferred_width_for_height (child_allocation.height, null,
						out child_allocation.width);
    }
  }

  public override void realize () {
    set_realized (true);

    Gtk.Allocation allocation;
    get_allocation (out allocation);

    Gdk.WindowAttr attributes = {};
    attributes.x = allocation.x;
    attributes.y = allocation.y;
    attributes.width = allocation.width;
    attributes.height = allocation.height;
    attributes.window_type = Gdk.WindowType.CHILD;
    attributes.wclass = Gdk.WindowWindowClass.INPUT_OUTPUT;
    attributes.visual = get_visual ();
    attributes.event_mask = get_events () | Gdk.EventMask.EXPOSURE_MASK;

    var attributes_mask = Gdk.WindowAttributesType.X | Gdk.WindowAttributesType.Y | Gdk.WindowAttributesType.VISUAL;
    view_window = new Gdk.Window (get_parent_window (),
				  attributes, attributes_mask);

    set_window (view_window);
    view_window.set_user_data (this);

    Gtk.Allocation child_allocation = { };
    get_child_allocation (allocation, out child_allocation);

    attributes.x = 0;
    attributes.y = 0;
    attributes.width = child_allocation.width;
    attributes.height = child_allocation.height;

    if (orientation == Gtk.Orientation.HORIZONTAL)
      attributes.y = allocation.height - child_allocation.height;
    else
      attributes.x = allocation.width - child_allocation.width;

    bin_window = new Gdk.Window (view_window, attributes, attributes_mask);
    bin_window.set_user_data (this);

    var child = get_child ();
    if (child != null)
      child.set_parent_window (bin_window);

    var context = get_style_context ();
    context.set_background (view_window);
    context.set_background (bin_window);

    bin_window.show ();
  }

  public override void unrealize () {
    view_window.set_user_data (this);
    view_window.destroy ();
    view_window = null;

    base.unrealize ();
  }

  public override void add (Gtk.Widget child) {
    child.set_parent_window (bin_window);
    child.set_child_visible (current_pos != 0.0);
    base.add (child);
  }

  public override void style_updated () {
    base.style_updated ();

    if (get_realized ()) {
      var context = get_style_context ();
      context.set_background (bin_window);
      context.set_background (view_window);
    }
  }
  
  public override void size_allocate (Gtk.Allocation allocation) {
    set_allocation (allocation);

    Gtk.Allocation child_allocation = { };
    get_child_allocation (allocation, out child_allocation);

    var child = get_child ();
    if (child != null && child.get_visible ())
      child.size_allocate (child_allocation);

    if (get_realized ()) {
      if (get_mapped ()) {
	var window_visible = allocation.width > 0 && allocation.height > 0;

	if (!window_visible && view_window.is_visible ())
	  view_window.hide ();
	if (window_visible && !view_window.is_visible ())
	  view_window.show ();
      }
      view_window.move_resize (allocation.x, allocation.y,
			       allocation.width, allocation.height);
      int bin_x = 0;
      int bin_y = 0;
      if (orientation == Gtk.Orientation.HORIZONTAL)
	bin_y = allocation.height - child_allocation.height;
      else
	bin_x = allocation.width - child_allocation.width;

      bin_window.move_resize (bin_x, bin_y,
			      child_allocation.width, child_allocation.height);
    }
  }

  private void set_amount (double amount) {
    current_pos = amount;
    // We check target_pos here too, because we want to ensure we set
    // child_visible immediately when starting a reveal operation
    // otherwise the child widgets will not be properly realized
    // after the reveal returns.
    bool new_visible = amount != 0.0 || target_pos != 0.0;
    var child = get_child ();
    if (child != null && new_visible != child.get_child_visible ())
      child.set_child_visible (new_visible);
    queue_resize ();
  }

  private void animate_step (int64 now) {
    double t = 1.0;
    if (now < end_time)
      t = (now - start_time) / (double) (end_time - start_time);

    t = transition_ease_out_quad (t, 1.0);

    set_amount (source_pos + t * (target_pos - source_pos));
  }

  private bool animate_cb () {
    int64 now = get_monotonic_time ();

    animate_step (now);

    if (current_pos == target_pos) {
      timeout = 0;
      return false;
    }
    return true;
  }

  private void start_animation (double target) {
    if (target_pos == target)
      return;

    target_pos = target;

    if (get_mapped ()) {
      source_pos = current_pos;
      start_time = get_monotonic_time ();
      end_time = start_time + duration * 1000;
      if (timeout == 0)
	timeout = Gdk.threads_add_timeout (frame_time, animate_cb);

      animate_step (start_time);
    } else {
      set_amount (target);
    }
  }

  private void stop_animation () {
    current_pos = target_pos;
    if (timeout != 0) {
      Source.remove (timeout);
      timeout = 0;
    }
  }

  public override void map () {
    if (!get_mapped ()) {
      Gtk.Allocation allocation;
      get_allocation (out allocation);
      
      if (allocation.width > 0 && allocation.height > 0)
	view_window.show ();

      start_animation (target_pos);
    }

    base.map ();
  }

  public override void unmap () {
    base.unmap ();
    stop_animation ();
  }

  public override bool draw (Cairo.Context cr) {
    if (Gtk.cairo_should_draw_window (cr, bin_window)) {
	base.draw (cr);
    }
    return true;
  }

  public void reveal () {
    start_animation (1.0);
  }

  public void unreveal () {
    start_animation (0.0);
  }

  // These all report only the natural height, because its not really
  // possible to allocate the right size during animation if the child
  // size can change
  public override void get_preferred_height (out int minimum_height,
					     out int natural_height) {
    base.get_preferred_height (out minimum_height, out natural_height);
    if (orientation == Gtk.Orientation.HORIZONTAL) {
      natural_height = (int) (natural_height * current_pos);
    }
    minimum_height = natural_height;
  }

  public override void get_preferred_height_for_width (int width,
						       out int minimum_height,
						       out int natural_height) {
    base.get_preferred_height_for_width (width, out minimum_height, out natural_height);
    if (orientation == Gtk.Orientation.HORIZONTAL) {
      natural_height = (int) (natural_height * current_pos);
    }
    minimum_height = natural_height;
  }

  public override void get_preferred_width (out int minimum_width,
					    out int natural_width) {
    base.get_preferred_width (out minimum_width, out natural_width);
    if (orientation == Gtk.Orientation.VERTICAL) {
      natural_width = (int) (natural_width * current_pos);
    }
    minimum_width = natural_width;
  }

  public override void get_preferred_width_for_height (int height,
						       out int minimum_width,
						       out int natural_width) {
    base.get_preferred_width_for_height (height, out minimum_width, out natural_width);
    if (orientation == Gtk.Orientation.VERTICAL) {
      natural_width = (int) (natural_width * current_pos);
    }
    minimum_width = natural_width;
  }
}
