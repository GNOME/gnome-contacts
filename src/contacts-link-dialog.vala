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

public class Contacts.LinkDialog : Dialog {
  private Entry filter_entry;
  private View view;
  private uint filter_entry_changed_id;

  const int PROFILE_SIZE = 96;

  private Widget display_card (Contact contact) {
    var grid = new Grid ();
    grid.set_vexpand (false);
    grid.set_valign (Align.START);
    grid.set_column_spacing (3);
    grid.set_row_spacing (8);

    var image_frame = new ContactFrame (PROFILE_SIZE);
    image_frame.set_image (contact.individual);
    // Put the frame in a grid so its not expanded
    var ig = new Grid ();
    ig.add (image_frame);
    grid.attach (ig, 0, 0, 1, 4);

    var l = new Label (null);
    l.set_markup ("<span font='22'><b>" + contact.display_name + "</b></span>");
    l.set_hexpand (true);
    l.set_halign (Align.START);
    l.set_valign (Align.START);
    l.set_ellipsize (Pango.EllipsizeMode.END);
    l.xalign = 0.0f;
    grid.attach (l, 1, 0, 1, 1);

    var nick = contact.individual.nickname;
    if (nick != null && nick.length > 0) {
      l = new Label ("\xE2\x80\x9C" + nick + "\xE2\x80\x9D");
      l.set_halign (Align.START);
      l.set_valign (Align.START);
      l.set_ellipsize (Pango.EllipsizeMode.END);
      l.xalign = 0.0f;
      grid.attach (l, 1, 1, 1, 1);
    }

    var merged_presence = contact.create_merged_presence_widget ();
    merged_presence.set_halign (Align.START);
    merged_presence.set_valign (Align.END);
    merged_presence.set_vexpand (true);
    grid.attach (merged_presence, 1, 3, 1, 1);

    return grid;
  }

  public LinkDialog (Contact contact) {
    set_title (_("Link Contact"));
    set_transient_for (App.app);
    set_modal (true);
    add_buttons (Stock.CLOSE,  null);

    view = new View (contact.store);
    var list = new ViewWidget (view);

    var grid = new Grid ();
    (get_content_area () as Container).add (grid);

    var left_grid = new Grid ();
    left_grid.set_orientation (Orientation.VERTICAL);
    left_grid.set_border_width (10);
    left_grid.set_column_spacing (8);
    grid.attach (left_grid, 0, 0, 1, 1);

    var card = display_card (contact);
    left_grid.add (card);

    var label = new Label (null);
    label.set_markup ("<span font='14'>" + _("Linked contacts") + "</span>");
    left_grid.add (label);
    label.xalign = 0.0f;

    var list_grid = new Grid ();
    grid.attach (list_grid, 1, 0, 1, 1);
    list_grid.set_orientation (Orientation.VERTICAL);

    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);
    list_grid.add (toolbar);

    filter_entry = new Entry ();
    filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    filter_entry.changed.connect (filter_entry_changed);
    filter_entry.icon_press.connect (filter_entry_clear);

    var search_entry_item = new ToolItem ();
    search_entry_item.is_important = false;
    search_entry_item.set_expand (true);
    search_entry_item.add (filter_entry);
    toolbar.add (search_entry_item);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_min_content_width (310);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.add (list);
    list_grid.add (scrolled);

    response.connect ( (response_id) => {
	this.destroy ();
      });

    set_default_size (710, 510);
  }

  private void refilter () {
    string []? values;
    string str = filter_entry.get_text ();

    if (str.length == 0)
      values = null;
    else {
      str = str.casefold();
      values = str.split(" ");
    }

    view.set_filter_values (values);
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
}
