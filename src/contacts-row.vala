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

public class Contacts.RowGroup : Object {
  public struct ColumnInfo {
    int min_width;
    int nat_width;
    int max_width;
    int prio;
    int spacing;
  }

  public int n_columns;
  private ColumnInfo[] column_info;

  int[] cached_widths;
  int cached_widths_for_width;

  Gee.ArrayList<unowned Row> rows;

  public RowGroup (int n_columns) {
    this.n_columns = n_columns;

    column_info = new ColumnInfo[n_columns];
    for (int i = 0; i < n_columns; i++) {
      column_info[i].min_width = 0;
      column_info[i].nat_width = -1;
      column_info[i].max_width = -1;
      column_info[i].prio = 0;
      column_info[i].spacing = 0;
    }

    rows = new Gee.ArrayList<Row>();
  }

  public ColumnInfo *get_column_info (int col) {
    return &column_info[col];
  }

  public void add (Row row) {
    rows.add (row);
    row.destroy.connect ( (widget) => {
	rows.remove (row);
      });
  }

  private void queue_resize () {
    foreach (unowned Row row in rows) {
      if (row.get_visible ())
	row.queue_resize ();
    }
  }

  public void set_column_priority (int column, int priority) {
    if (column >= n_columns)
      return;

    column_info[column].prio = priority;

    cached_widths = null;
    queue_resize ();
  }

  public void set_column_min_width (int column, int min_width) {
    if (column >= n_columns)
      return;

    column_info[column].min_width = min_width;
    cached_widths = null;
    queue_resize ();
  }

  public void set_column_max_width (int column, int max_width) {
    if (column >= n_columns)
      return;

    column_info[column].max_width = max_width;
    cached_widths = null;
    queue_resize ();
  }

  public void set_column_spacing (int column, int spacing) {
    if (column >= n_columns)
      return;

    column_info[column].spacing = spacing;
    cached_widths = null;
    queue_resize ();
  }

  public int[] distribute_widths (int width) {
    if (cached_widths != null &&
	cached_widths_for_width == width)
      return cached_widths;

    int max_prio = 0;
    var widths = new int[n_columns];

    /* First distribute the min widths */
    for (int i = 0; i < n_columns; i++) {
      var info = &column_info[i];

      if (info->prio > max_prio)
	max_prio = info->prio;

      if (width > info.min_width) {
	widths[i] = info.min_width;
	width -= info.min_width;
      } else if (width > 0) {
	widths[i] = width;
	width = 0;
      } else {
	widths[i] = 0;
      }
      width -= info.spacing;
    }

    /* Distribute remaining width equally among
       children with same priority, up to max */
    for (int prio = max_prio; width > 0 && prio >= 0; prio--) {
      int n_children;

      while (width > 0) {
	n_children = 0;
	int max_extra = width;

	for (int i = 0; i < n_columns; i++) {
	  var info = &column_info[i];

	  if (info.prio == prio &&
	      (info.max_width < 0 ||
	       widths[i] < info.max_width)) {
	    n_children++;

	    if (info.max_width >= 0 &&
		info.max_width - widths[i] < max_extra)
	      max_extra = info.max_width - widths[i];
	  }
	}

	if (n_children == 0)
	  break; // No more unsatisfied children on this prio

	int distribute = int.min (width, max_extra * n_children);
	width -= distribute;

	int per_child = distribute / n_children;
	int per_child_extra = distribute % n_children;
	int per_child_extra_sum = 0;

	for (int i = 0; i < n_columns; i++) {
	  var info = &column_info[i];

	  if (info.prio == prio &&
	      (info.max_width < 0 ||
	       widths[i] < info.max_width)) {
	    widths[i] += per_child;
	    per_child_extra_sum += per_child_extra;
	    if (per_child_extra_sum > distribute) {
	      widths[i] += 1;
	      per_child_extra_sum -= distribute;
	    }
	  }
	}
      }
    }

    cached_widths = widths;
    cached_widths_for_width = width;
    return widths;
  }

  public void get_width (out int minimum_width, out int natural_width) {
    minimum_width = 0;
    natural_width = 0;

    for (int i = 0; i < n_columns; i++) {
      minimum_width += column_info[i].min_width;
      if (column_info[i].nat_width >= 0)
	natural_width += column_info[i].nat_width;
      else if (column_info[i].max_width >= 0)
	natural_width += column_info[i].max_width;
      else
	natural_width += column_info[i].min_width;
      minimum_width += column_info[i].spacing;
      natural_width += column_info[i].spacing;
    }
  }

  public bool is_expanding () {
    for (int i = 0; i < n_columns; i++) {
      var info = &column_info[i];
      if (info.max_width == -1 &&
	  info.max_width !=  info.min_width) {
	return true;
      }
    }
    return false;
  }
}

public class Contacts.Row : Container {
  struct RowInfo {
    int min_height;
    int nat_height;
    bool expand;
  }

  struct Child {
    Widget? widget;
  }

  private Gdk.Window event_window;
  RowGroup group;
  int n_rows;
  Child[,] row_children;

  public Row (RowGroup group) {
    this.group = group;
    group.add (this);

    set_has_window (false);
    set_redraw_on_allocate (false);
    set_hexpand (true);

    n_rows = 1;
    row_children = new Child[group.n_columns, n_rows];
  }

  public override void realize () {
    Allocation allocation;
    get_allocation (out allocation);
    set_realized (true);

    Gdk.WindowAttr attributes = { };
    attributes.x = allocation.x;
    attributes.y = allocation.y;
    attributes.width = allocation.width;
    attributes.height = allocation.height;
    attributes.window_type = Gdk.WindowType.CHILD;
    attributes.event_mask = this.get_events () | Gdk.EventMask.EXPOSURE_MASK | Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK;

    var window = get_parent_window ();
    this.set_window (window);

    attributes.wclass = Gdk.WindowWindowClass.ONLY;
    event_window = new Gdk.Window (window, attributes, Gdk.WindowAttributesType.X | Gdk.WindowAttributesType.Y);
    event_window.set_user_data (this);
  }

  public override void unrealize () {
    event_window.set_user_data (null);
    event_window.destroy ();
    event_window = null;
    base.unrealize ();
  }

  public override void map () {
    event_window.show ();
    base.map ();
  }

  public override void unmap () {
    event_window.hide ();
    base.unmap ();
  }

  public void attach (Widget widget, int attach_col, int attach_row) {
    if (attach_col >= group.n_columns) {
      warning ("Tryint to attach widget to non-existing column");
      return;
    }

    if (attach_row >= n_rows) {
      int old_n_rows = n_rows;

      n_rows = attach_row + 1;

      var old_row_children = (owned)row_children;
      row_children = new Child[group.n_columns, n_rows];

      for (int row = 0; row < n_rows; row++) {
	for (int col = 0; col < group.n_columns; col++) {
	  if (row < old_n_rows &&
	      col < group.n_columns) {
	    row_children[col, row] = (owned)old_row_children[col, row];
	  }
	}
      }
    }

    Child *child_info = &row_children[attach_col, attach_row];
    if (child_info.widget != null) {
      remove (child_info.widget);
    }

    child_info.widget = widget;
    widget.set_parent (this);
  }

  public override void add (Widget widget) {
    for (int row = 0; row < n_rows; row++) {
      for (int col = 0; col < group.n_columns; col++) {
	Child *child_info = &row_children[col, row];
	if (child_info.widget == null) {
	  attach (widget, col, row);
	  return;
	}
      }
    }
    attach (widget, 0, n_rows);
  }

  public override void remove (Widget widget) {
    for (int row = 0; row < n_rows; row++) {
      for (int col = 0; col < group.n_columns; col++) {
	Child *child_info = &row_children[col, row];
	if (child_info.widget == widget) {
          bool was_visible = widget.get_visible ();

          widget.unparent ();

	  child_info.widget = null;

          if (was_visible && this.get_visible ())
            this.queue_resize ();

          return;
	}
      }
    }
  }

  public override void forall_internal (bool include_internals,
					Gtk.Callback callback) {
    for (int row = 0; row < n_rows; row++) {
      for (int col = 0; col < group.n_columns; col++) {
	Child *child_info = &row_children[col, row];
	if (child_info.widget != null) {
	  callback (child_info.widget);
	}
      }
    }
  }

  public override void compute_expand_internal (out bool hexpand, out bool vexpand) {
    hexpand = group.is_expanding ();

    vexpand = false;
    for (int row = 0; row < n_rows; row++) {
      for (int col = 0; col < group.n_columns; col++) {
	Child *child_info = &row_children[col, row];
	if (child_info.widget != null) {
	  vexpand |= child_info.widget.compute_expand (Orientation.VERTICAL);
	}
      }
    }
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
    get_preferred_height_for_width (natural_width, out minimum_height, out natural_height);
  }


  int[] distribute_heights (int height, RowInfo[] row_info) {
    var heights = new int[n_rows];

    /* First distribute the min heights */
    for (int i = 0; i < n_rows; i++) {
      RowInfo *info = &row_info[i];

      if (height > info.min_height) {
	heights[i] = info.min_height;
	height -= info.min_height;
      } else if (height > 0) {
	heights[i] = height;
	height = 0;
      } else {
	heights[i] = 0;
      }
    }

    /* Distribute remaining height equally among
       children that have not filled up their natural size */
    int n_children;

    while (height > 0) {
      n_children = 0;
      int max_extra = height;

      for (int i = 0; i < n_rows; i++) {
	RowInfo *info = &row_info[i];

	if (info.expand || heights[i] < info.nat_height) {
	  n_children++;

	  if (info.nat_height < heights[i] &&
	      info.nat_height - heights[i] < max_extra)
	    max_extra = info.nat_height - heights[i];
	}
      }

      if (n_children == 0)
	break;

      int distribute = int.min (height, max_extra * n_children);
      height -= distribute;

      int per_child = distribute / n_children;
      int per_child_extra = distribute % n_children;
      int per_child_extra_sum = 0;

      for (int i = 0; i < n_rows; i++) {
	RowInfo *info = &row_info[i];

	if (heights[i] < info.nat_height ||
	    n_children == n_rows) {
	  heights[i] += per_child;
	  per_child_extra_sum += per_child_extra;
	  if (per_child_extra_sum > distribute) {
	    heights[i] += 1;
	    per_child_extra_sum -= distribute;
	  }
	}
      }
    }

    return heights;
  }

  private RowInfo[] get_row_heights_for_widths (int[] widths) {
    RowInfo[] info = new RowInfo[n_rows];

    for (int row = 0; row < n_rows; row++) {
      int row_min = 0, row_nat = 0;
      bool first = true;
      bool expand = false;

      for (int col = 0; col < group.n_columns; col++) {
	Child *child_info = &row_children[col, row];
	if (child_info.widget != null) {
	  int child_min, child_nat;

	  child_info.widget.get_preferred_height_for_width (widths[col], out child_min, out child_nat);

	  expand |= child_info.widget.compute_expand (Orientation.VERTICAL);

	  if (first) {
	    first = false;
	    row_min = child_min;
	    row_nat = child_nat;
	  } else {
	    row_min = int.max (row_min, child_min);
	    row_nat = int.max (row_nat, child_nat);
	  }
	}
      }
      info[row].min_height = row_min;
      info[row].nat_height = row_nat;
      info[row].expand = expand;
    }
    return info;
  }

  public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height) {
    var widths = group.distribute_widths (width);
    var row_info = get_row_heights_for_widths (widths);

    minimum_height = 0;
    natural_height = 0;

    for (int row = 0; row < n_rows; row++) {
      minimum_height += row_info[row].min_height;
      natural_height += row_info[row].nat_height;
    }
  }

  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    group.get_width (out minimum_width, out natural_width);
  }

  public override void get_preferred_width_for_height (int height, out int minimum_width, out int natural_width) {
    get_preferred_width (out minimum_width, out natural_width);
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    var widths = group.distribute_widths (allocation.width);
    var row_info = get_row_heights_for_widths (widths);
    var heights = distribute_heights (allocation.height, row_info);

    set_allocation (allocation);

    if (event_window != null)
      event_window.move_resize (allocation.x,
                                allocation.y,
                                allocation.width,
                                allocation.height);

    int y = 0;
    for (int row = 0; row < n_rows; row ++) {
      int x = 0;
      for (int col = 0; col < group.n_columns; col++) {
	Child *child_info = &row_children[col, row];
	if (child_info.widget != null) {
	  Allocation child_allocation = { 0, 0, 0, 0};

	  child_allocation.width = widths[col]; // calculate_child_width (child_info.widget, widths[col]);
	  child_allocation.height = heights[row];

	  if (get_direction () == TextDirection.RTL)
	    child_allocation.x = allocation.x + allocation.width - x - child_allocation.width;
	  else
	    child_allocation.x = allocation.x + x;
	  child_allocation.y = allocation.y + y;
	  child_info.widget.size_allocate (child_allocation);
	}
	x += widths[col] + group.get_column_info (col).spacing;
      }
      y += heights[row];
    }
  }
}
