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
using Contacts;

public bool need_separator (Widget widget, Widget? before)
{
	if (before == null) {
		return true;
	}
	var text = (widget as Label).get_text ();
	return strcmp (text, "blah3") == 0;
}

public Widget create_separator ()
{
	var l = new Button.with_label ("label");
	return l;
}

public void update_separator (Widget separator,
							  Widget child,
							  Widget? before_widget)
{
	var text = (child as Label).get_text ();
	(separator as Button).set_label ("Label %s".printf (text));
}



public static int
compare_label (Widget a, Widget b) {
	var aa = (a as Label).get_text ();
	var bb = (b as Label).get_text ();
	return strcmp (aa, bb);
}

public static int
compare_label_reverse (Widget a, Widget b) {
	return - compare_label (a, b);
}

public static bool
filter (Widget widget) {
	var text = (widget as Label).get_text ();
	return strcmp (text, "blah3") != 0;
}

public static int
main (string[] args) {

  Gtk.init (ref args);

  var w = new Window ();
  var hbox = new Box(Orientation.HORIZONTAL, 0);
  w.add (hbox);

  var sorted = new Sorted();
  hbox.add (sorted);

  sorted.add (new Label ("blah4"));
  var l3 = new Label ("blah3");
  sorted.add (l3);
  sorted.add (new Label ("blah1"));
  sorted.add (new Label ("blah2"));

  var vbox = new Box(Orientation.VERTICAL, 0);
  hbox.add (vbox);

  var b = new Button.with_label ("sort");
  vbox.add (b);
  b.clicked.connect ( () => {
		  sorted.set_sort_func (compare_label);
	  });

  b = new Button.with_label ("reverse");
  vbox.add (b);
  b.clicked.connect ( () => {
		  sorted.set_sort_func (compare_label_reverse);
	  });

  b = new Button.with_label ("change");
  vbox.add (b);
  b.clicked.connect ( () => {
		  if (l3.get_text () == "blah3")
			  l3.set_text ("blah5");
		  else
			  l3.set_text ("blah3");
		  sorted.child_changed (l3);
	  });

  b = new Button.with_label ("filter");
  vbox.add (b);
  b.clicked.connect ( () => {
		  sorted.set_filter_func (filter);
	  });

  b = new Button.with_label ("unfilter");
  vbox.add (b);
  b.clicked.connect ( () => {
		  sorted.set_filter_func (null);
	  });

  int new_button_nr = 1;
  b = new Button.with_label ("add");
  vbox.add (b);
  b.clicked.connect ( () => {
		  var l = new Label ("blah2 new %d".printf (new_button_nr++));
		  sorted.add (l);
		  l.show ();
	  });

  b = new Button.with_label ("separate");
  vbox.add (b);
  b.clicked.connect ( () => {
		  sorted.set_separator_funcs (need_separator,
									  create_separator,
									  update_separator);
	  });

  b = new Button.with_label ("unseparate");
  vbox.add (b);
  b.clicked.connect ( () => {
		  sorted.set_separator_funcs (null, null, null);
	  });


  w.show_all ();

  Gtk.main ();

  return 0;
}
