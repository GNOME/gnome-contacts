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
using Gee;

/* Requriements:
   + sort
   + filter
   + first char or type custom "separators"
     (create, destroy, update)
   + Work with largish sets of children

   filter => child visibility setting

   Q:
   How to construct separators?
   What about resort a single item, can be problem if more change
    at the same time, need a stable sort...
   
   settings:
	  sort function
	  filter function
	  needs_separator function
	  create_separator
	  update_separator (if the child below it changes)

	ops:
	  child-changed (resort, refilter, 
	  resort-all
	  refilter-all

	Impl:
	 GSequence for children
	 GHashTable for child to iter mapping
*/

public class Contacts.Sorted : Container {
  public delegate bool FilterFunc (Widget child);
  public delegate bool NeedSeparatorFunc (Widget? before, Widget widget);
  public delegate Widget CreateSeparatorFunc (Widget child);
  public delegate void UpdateSeparatorFunc (Widget separator, Widget child);

  struct ChildInfo {
    Widget widget;
    bool is_separator;
    bool has_separator;
    int height;
    SequenceIter<ChildInfo?> iter;
  }

  Sequence<ChildInfo?> children;
  HashMap<unowned Widget, unowned ChildInfo?> child_hash;
  CompareDataFunc<Widget>? sort_func;
  FilterFunc? filter_func;
  NeedSeparatorFunc? need_separator_func;
  CreateSeparatorFunc? create_separator_func;

  private int do_sort (ChildInfo? a, ChildInfo? b) {
    return sort_func (a.widget, b.widget);
  }

  public Sorted () {
    set_has_window (false);
    set_redraw_on_allocate (false);

    children = new Sequence<ChildInfo?>();
    child_hash = new HashMap<unowned Widget, unowned ChildInfo?> ();
  }

  private void apply_filter (Widget child) {
    bool do_show = true;
    if (filter_func != null)
      do_show = filter_func (child);
    child.set_child_visible (do_show);
  }

  private void apply_filter_all () {
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo? child_info = iter.get ();
      apply_filter (child_info.widget);
    }
  }

  public void set_filter_func (owned FilterFunc? f) {
    filter_func = (owned)f;
    refilter ();
  }
  
  public void refilter () {
    apply_filter_all ();
    queue_resize ();
  }
  
  public void resort () {
    children.sort (do_sort);
    queue_resize ();
  }
  
  public void set_sort_func (owned CompareDataFunc<Widget>? f) {
    sort_func = (owned)f;
    resort ();
  }

  public override void map () {
    base.map ();
  }

  public override void unmap () {
    base.unmap ();
  }

  private unowned ChildInfo? lookup_info (Widget widget) {
    return child_hash.get (widget);
  }
  
  public override void add (Widget widget) {
    ChildInfo? the_info = { widget };
    unowned ChildInfo? info = the_info;
    SequenceIter<ChildInfo?> iter;
    
    child_hash.set (widget, info);
    
    if (sort_func != null)
      iter = children.insert_sorted ((owned) the_info, do_sort);
    else
      iter = children.append ((owned) the_info);

    apply_filter (widget);
    
    info.iter = iter;

    widget.set_parent (this);
  }

  public void child_changed (Widget widget) {
    unowned ChildInfo? info = lookup_info (widget);
    if (info == null)
      return;

    if (sort_func != null) {
      children.sort_changed (info.iter, do_sort);
      this.queue_resize ();
    }
    apply_filter (info.widget);
  }
  
  public override void remove (Widget widget) {
    unowned ChildInfo? info = lookup_info (widget);
    if (info == null)
      return;

    bool was_visible = widget.get_visible ();
    widget.unparent ();

    child_hash.unset (widget);
    
    if (was_visible && this.get_visible ())
      this.queue_resize ();
  }

  public override void forall_internal (bool include_internals,
					Gtk.Callback callback) {
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo? child_info = iter.get ();
      callback (child_info.widget);
    }
  }

  public override void compute_expand_internal (out bool hexpand, out bool vexpand) {
    base.compute_expand_internal (out hexpand, out vexpand);
    /* We don't expand vertically beyound the minimum size */
    vexpand = false;
  }
  
  public override Type child_type () {
    return typeof (Widget);
  }

  public override Gtk.SizeRequestMode get_request_mode () {
    return SizeRequestMode.HEIGHT_FOR_WIDTH;
  }

  public override void get_preferred_height (out int minimum_height, out int natural_height) {
    int natural_width;
    get_preferred_width (null, out natural_width);
    get_preferred_height_for_width_internal (natural_width, out minimum_height, out natural_height);
  }

  public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height) {
    minimum_height = 0;
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo? child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      int child_min;

      if (!widget.get_visible () || !widget.get_child_visible ())
	continue;
      
      widget.get_preferred_height_for_width (width, out child_min, null);
      minimum_height += child_min;
    }
    /* We always allocate the minimum height, since handling
       expanding rows is way too costly, and unlikely to
       be used, as lists are generally put inside a scrolling window
       anyway.
    */
    natural_height = minimum_height;
  }

  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    minimum_width = 0;
    natural_width = 0;
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo? child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      int child_min, child_nat;

      if (!widget.get_visible () || !widget.get_child_visible ())
	continue;
      
      widget.get_preferred_width (out child_min, out child_nat);
      minimum_width = int.max (minimum_width, child_min);
      natural_width = int.max (natural_width, child_nat);
    }
  }

  public override void get_preferred_width_for_height (int height, out int minimum_width, out int natural_width) {
    get_preferred_width (out minimum_width, out natural_width);
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    Allocation child_allocation = { 0, 0, 0, 0};

    set_allocation (allocation);
    
    child_allocation.x = allocation.x;
    child_allocation.y = allocation.y;
    child_allocation.width = allocation.width;

    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo? child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      int child_min;

      if (!widget.get_visible () || !widget.get_child_visible ())
	continue;
      
      widget.get_preferred_height_for_width (allocation.width, out child_min, null);
      child_allocation.height = child_info.height = child_min;

      widget.size_allocate (child_allocation);
      
      child_allocation.y += child_min;
    }
  }
}
