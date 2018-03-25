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

/**
 * The MaxWidthBin is a very basic helper class to restrict a given widget's
 * width to a given maximum. Set the widget as the child of this Bin to
 * restrict its width.
 */
public class Contacts.MaxWidthBin : Gtk.Bin {

  public int max_width { get; set; }

  public override void get_preferred_height (out int minimum_height, out int natural_height) {
    var child = get_child ();
    if (child != null) {
      int min, nat;
      child.get_preferred_height (out min, out nat);
      minimum_height = min;
      natural_height = nat;
    } else {
      minimum_height = -1;
      natural_height = -1;
    }
  }

  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    var child = get_child ();
    if (child != null) {
      int min, nat;
      child.get_preferred_width (out min, out nat);
      minimum_width = min;
      natural_width = nat;
    } else {
      minimum_width = -1;
      natural_width = -1;
    }
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    Gtk.Allocation new_alloc;

    set_allocation (allocation);
    new_alloc = allocation;
    if (allocation.width > this.max_width) {
      new_alloc.width = this.max_width;
      new_alloc.x = allocation.x;
    }

    var child = get_child ();
    child.size_allocate (new_alloc);
  }
}
