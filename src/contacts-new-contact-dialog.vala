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
using Gee;

public class Contacts.NewContactDialog : Dialog {
  Grid grid;
  Entry name_entry;
  ArrayList<Entry> email_entries;
  ArrayList<TypeCombo> email_combos;
  ArrayList<Entry> phone_entries;
  ArrayList<TypeCombo> phone_combos;
  ArrayList<Grid> address_entries;
  ArrayList<TypeCombo> address_combos;

  public NewContactDialog(Window parent) {
    set_title (_("New contact"));
    set_destroy_with_parent (true);
    set_transient_for (parent);

    add_buttons (Stock.CANCEL, ResponseType.CANCEL,
		 _("Create Contact"), ResponseType.OK);

    set_default_response (ResponseType.OK);

    var box = get_content_area () as Box;

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_size_request (430, 600);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_shadow_type (ShadowType.IN);
    scrolled.set_border_width (6);

    box.pack_start (scrolled, true, true, 0);

    grid = new Grid ();
    grid.set_border_width (12);
    grid.set_column_spacing (10);
    grid.set_row_spacing (4);
    scrolled.add_with_viewport (grid);

    var frame = new Frame (null);
    frame.set_size_request (96, 96);
    frame.set_hexpand (false);
    frame.set_vexpand (false);
    var l = new Label (_("Add or \nselect a picture"));
    frame.add (l);
    grid.attach (frame, 0, 0, 1, 2);

    name_entry = new Entry ();
    name_entry.set_hexpand (true);
    name_entry.set_vexpand (false);
    name_entry.set_halign (Align.FILL);
    grid.attach (name_entry, 1, 0, 2, 1);

    l = new Label (_("Contact Name"));
    l.set_halign (Align.START);
    l.set_vexpand (false);
    l.set_valign (Align.START);
    grid.attach (l, 1, 1, 2, 1);

    int y = 2;

    pack_label (_("Email"), ref y);

    email_entries = new Gee.ArrayList<Entry>();
    email_combos = new Gee.ArrayList<TypeCombo>();

    pack_entry_combo (email_entries, email_combos, TypeSet.general, ref y);

    pack_spacing (12, ref y);

    pack_label (_("Phone"), ref y);

    phone_entries = new Gee.ArrayList<Entry>();
    phone_combos = new Gee.ArrayList<TypeCombo>();

    pack_entry_combo (phone_entries, phone_combos, TypeSet.phone, ref y);

    pack_spacing (12, ref y);

    pack_label (_("Address"), ref y);

    address_entries = new Gee.ArrayList<Grid>();
    address_combos = new Gee.ArrayList<TypeCombo>();

    pack_address_combo (address_entries, address_combos, TypeSet.general, ref y);

    pack_spacing (16, ref y);

    var menu_button = new MenuButton (_("Add Detail"));
    grid.attach (menu_button, 0, y, 2, 1);
    menu_button.set_hexpand (false);
    menu_button.set_halign (Align.START);

    var menu = new Menu ();
    menu_button.set_menu (menu);

    Utils.add_menu_item (menu, _("Email")).activate.connect ( () => {
	int row = row_after (email_entries.get (email_entries.size - 1));
	pack_entry_combo (email_entries, email_combos, TypeSet.general, ref row);
	grid.show_all ();
      });
    Utils.add_menu_item (menu, _("Phone")).activate.connect ( () => {
	int row = row_after (phone_entries.get (phone_entries.size - 1));
	pack_entry_combo (phone_entries, phone_combos, TypeSet.phone, ref row);
	grid.show_all ();
      });
    Utils.add_menu_item (menu, _("Address")).activate.connect ( () => {
	int row = row_after (address_entries.get (address_entries.size - 1));
	pack_address_combo (address_entries, address_combos, TypeSet.general, ref row);
	grid.show_all ();
      });
  }

  int row_after (Widget widget) {
    int row;
    grid.child_get (widget, "top-attach", out row);
    grid.insert_row (row + 1);
    return row + 1;
  }

  void pack_label (string text, ref int row) {
    var l = new Label (text);
    l.set_halign (Align.START);
    grid.attach (l, 0, row++, 1, 1);
  }

  void pack_spacing (int height, ref int row) {
    var a = new Alignment(0,0,0,0);
    a.set_size_request (-1, height);
    grid.attach (a, 0, row++, 2, 1);
  }

  void pack_entry_combo (Gee.ArrayList<Entry> entries, Gee.ArrayList<TypeCombo> combos, TypeSet type_set, ref int row) {
    var entry = new Entry ();
    entries.add (entry);
    entry.set_hexpand (true);
    grid.attach (entry, 0, row, 2, 1);

    var combo = new TypeCombo (type_set);
    combo.set_hexpand (false);
    combos.add (combo);
    grid.attach (combo, 2, row, 1, 1);

    combo.set_to ("HOME");

    row++;
  }

  void pack_address_combo (Gee.ArrayList<Grid> entries, Gee.ArrayList<TypeCombo> combos, TypeSet type_set, ref int row) {
    Grid sub_grid = new Grid ();
    sub_grid.set_orientation (Orientation.VERTICAL);
    sub_grid.set_hexpand (true);
    entries.add (sub_grid);

    for (int i = 0; i < Contact.postal_element_props.length; i++) {
      var entry = new Entry ();
      entry.set ("placeholder-text", Contact.postal_element_names[i]);
      entry.set_hexpand (true);
      sub_grid.attach (entry, 0, i, 1, 1);
    }

    grid.attach (sub_grid, 0, row, 2, 1);

    var combo = new TypeCombo (type_set);
    combo.set_hexpand (false);
    combos.add (combo);
    grid.attach (combo, 2, row, 1, 1);

    combo.set_to ("HOME");

    row++;
  }

  public override bool map_event (Gdk.EventAny e) {
    var r = base.map_event (e);
    name_entry.grab_focus ();
    return r;
  }

  public override void response (int response_id) {
    if (response_id == ResponseType.OK) {
      if (name_entry.get_text () == "") {
	var d = new MessageDialog (this,
				   DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
				   MessageType.ERROR,
				   ButtonsType.CLOSE,
				   _("You must specify a contact name"));
	d.show_all ();
	d.response.connect ( (response_id) => {
	    d.destroy ();
	  });
	return;
      }
    }
    this.destroy ();
  }
}
