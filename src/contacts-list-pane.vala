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

public class Contacts.ListPane : Frame {
  private Store contacts_store;
  private View contacts_view;
  private ViewWidget list;
  public Entry filter_entry;
  private uint filter_entry_changed_id;
  private ulong non_empty_id;
  private EventBox empty_box;
  private bool ignore_selection_change;

  public signal void selection_changed (Contact? contact);
  public signal void create_new ();

  private void refilter () {
    string []? values;
    string str = filter_entry.get_text ();

    if (str.length == 0)
      values = null;
    else {
      str = Utils.canonicalize_for_search (str);
      values = str.split(" ");
    }

    contacts_view.set_filter_values (values);
  }

  private bool filter_entry_changed_timeout () {
    filter_entry_changed_id = 0;
    refilter ();
    return false;
  }

  private void filter_entry_changed (Editable editable) {
    if (filter_entry_changed_id != 0)
      Source.remove (filter_entry_changed_id);

    filter_entry_changed_id = Timeout.add (300, filter_entry_changed_timeout);

    if (filter_entry.get_text () == "")
      filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    else
      filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-clear-symbolic");
  }

  private void filter_entry_clear (EntryIconPosition position) {
    filter_entry.set_text ("");
  }

  public ListPane (Store contacts_store) {
    this.contacts_store = contacts_store;
    this.contacts_view = new View (contacts_store);
    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);
    toolbar.set_hexpand (true);

    filter_entry = new Entry ();
    filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    filter_entry.changed.connect (filter_entry_changed);
    filter_entry.icon_press.connect (filter_entry_clear);

    var search_entry_item = new ToolItem ();
    search_entry_item.is_important = false;
    search_entry_item.set_expand (true);
    search_entry_item.add (filter_entry);
    toolbar.add (search_entry_item);

    var separator = new SeparatorToolItem ();
    separator.set_draw (false);
    toolbar.add (separator);

    var add_button = new ToolButton (null, null);
    add_button.set_icon_name ("list-add-symbolic");
    add_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    add_button.is_important = false;
    // We make the button slightly wider to look better since it
    // becomes taller when added to the toolbar
    add_button.set_size_request (34, -1);
    toolbar.add (add_button);
    add_button.clicked.connect ( (button) => {
	create_new ();
      });

    this.set_size_request (315, -1);
    this.set_hexpand (false);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.get_style_context ().set_junction_sides (JunctionSides.RIGHT | JunctionSides.LEFT | JunctionSides.TOP);

    var grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    this.add (grid);


    list = new ViewWidget (contacts_view);
    list.selection_changed.connect( (l, contact) => {
	if (!ignore_selection_change)
	  selection_changed (contact);
      });

    scrolled.add (list);
    list.show_all ();
    scrolled.set_no_show_all (true);

    empty_box = new EventBox ();
    empty_box.set_hexpand (false);
    empty_box.set_vexpand (true);
    empty_box.set_halign (Align.FILL);
    Gdk.RGBA white = {1, 1, 1, 1};
    empty_box.override_background_color (StateFlags.NORMAL, white);

    var empty_grid = new Grid ();
    empty_grid.set_row_spacing (8);
    empty_grid.set_orientation (Orientation.VERTICAL);
    empty_grid.set_valign (Align.CENTER);

    var image = new Image.from_icon_name ("avatar-default-symbolic", IconSize.DIALOG);
    image.get_style_context ().add_class ("dim-label");
    empty_grid.add (image);

    var label = new Label (_("Connect to an account,\nimport or add contacts"));
    label.xalign = 0.5f;
    label.set_hexpand (true);
    label.set_halign (Align.CENTER);
    empty_grid.add (label);

    var button = new Button.with_label (_("Online Accounts"));
    button.set_halign (Align.CENTER);
    empty_grid.add (button);
    button.clicked.connect ( (button) => {
	try {
	  Process.spawn_command_line_async ("gnome-control-center online-accounts");
	}
	catch (Error e) {
	  // TODO: Show error dialog
	}
      });

    empty_box.add (empty_grid);
    empty_box.show_all ();
    empty_box.set_no_show_all (true);

    grid.add (toolbar);
    grid.add (scrolled);
    grid.add (empty_box);

    this.show_all ();

    if (contacts_store.is_empty ()) {
      empty_box.show ();
      non_empty_id = contacts_store.added.connect ( (c) => {
	  empty_box.hide ();
	  scrolled.show ();
	  contacts_store.disconnect (non_empty_id);
	  non_empty_id = 0;
	});
    } else {
      scrolled.show ();
    }

  }

  public void select_contact (Contact contact, bool ignore_change = false) {
    if (ignore_change)
      ignore_selection_change = true;
    list.select_contact (contact);
    ignore_selection_change = false;
  }
}
