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
using Folks;

public class Contacts.ListPane : Frame {
  private Store contacts_store;
  private View contacts_view;
  private ViewWidget list;
  public Entry filter_entry;
  private uint filter_entry_changed_id;

  public signal void selection_changed (Contact? contact);
  public signal void create_new ();

  private void refilter () {
    string []? values;
    string str = filter_entry.get_text ();

    if (str.length == 0)
      values = null;
    else {
      str = str.casefold();
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

    var separator = new SeparatorToolItem ();
    separator.set_draw (false);
    toolbar.add (separator);

    filter_entry = new Entry ();
    filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    filter_entry.changed.connect (filter_entry_changed);
    filter_entry.icon_press.connect (filter_entry_clear);

    var search_entry_item = new ToolItem ();
    search_entry_item.is_important = false;
    search_entry_item.set_expand (true);
    search_entry_item.add (filter_entry);
    toolbar.add (search_entry_item);

    separator = new SeparatorToolItem ();
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

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_min_content_width (310);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.get_style_context ().set_junction_sides (JunctionSides.RIGHT | JunctionSides.LEFT | JunctionSides.TOP);

    var grid = new Grid ();
    this.add (grid);

    grid.attach (toolbar, 0, 0, 1, 1);
    grid.attach (scrolled, 0, 1, 1, 1);

    list = new ViewWidget (contacts_view);
    list.selection_changed.connect( (l, contact) => {
	selection_changed (contact);
      });

    scrolled.add (list);

    this.show_all ();
  }

  public void select_contact (Contact contact) {
    list.select_contact (contact);
  }
}
