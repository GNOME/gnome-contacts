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

public class Contacts.LinkDialog : Dialog {
  // TODO: Remove later when bound in vala
  private static unowned string C_(string context, string msgid) {
    return GLib.dpgettext2 (Config.GETTEXT_PACKAGE, context, msgid);
  }

  private Contact contact;
  private Contact? selected_contact;
  private Entry filter_entry;
  private View view;
  private ViewWidget list;
  private Grid persona_grid;
  private uint filter_entry_changed_id;

  private void update_personas () {
    // Remove previous personas
    foreach (var w in persona_grid.get_children ()) {
      w.destroy ();
    }

    // Add all current personas
    int i = 0;
    foreach (var p in contact.individual.personas) {
      var image_frame = new ContactFrame (48);
      image_frame.set_image (p as AvatarDetails);
      persona_grid.attach (image_frame, 0, i, 1, 2);

      var label = new Label ("");
      label.set_markup ("<span font='13'>" + Contact.get_display_name_for_persona (p) + "</span>");
      label.set_valign (Align.START);
      label.set_halign (Align.START);
      label.set_hexpand (true);
      label.xalign = 0.0f;
      label.set_ellipsize (Pango.EllipsizeMode.END);
      persona_grid.attach (label, 1, i, 1, 1);

      label = new Label ("");
      label.set_markup ("<span font='9'>" + Contact.format_persona_store_name (p.store) + "</span>");
      label.set_valign (Align.START);
      label.set_halign (Align.START);
      label.set_hexpand (true);
      label.xalign = 0.0f;
      label.set_ellipsize (Pango.EllipsizeMode.END);
      persona_grid.attach (label, 1, i+1, 1, 1);

      var button = new Button ();
      var image = new Image.from_icon_name ("list-remove-symbolic", IconSize.MENU);
      button.add (image);
      button.set_valign (Align.CENTER);
      button.set_halign (Align.END);
      persona_grid.attach (button, 1, i, 1, 2);
      button.clicked.connect ( (button) => {
	  unlink_persona.begin (contact, p, (obj, result) => {
	      unlink_persona.end (result);
	      update_personas ();
	    });
	});

      i += 2;
    }
    persona_grid.show_all ();
  }

  public LinkDialog (Contact contact) {
    this.contact = contact;
    set_title (_("Link Contact"));
    set_transient_for (App.app.window);
    set_modal (true);
    add_buttons (Stock.CLOSE,  null);

    view = new View (contact.store);
    view.hide_contact (contact);
    list = new ViewWidget (view, ViewWidget.TextDisplay.STORES);

    var grid = new Grid ();
    var container = (get_content_area () as Container);
    grid.set_border_width (8);
    grid.set_row_spacing (12);
    container.add (grid);

    var label = new Label (_("Select contacts to link to %s").printf (contact.display_name));
    label.set_valign (Align.CENTER);
    label.set_halign (Align.START);
    label.xalign = 0.0f;
    label.set_ellipsize (Pango.EllipsizeMode.END);
    grid.attach (label, 0, 0, 1, 1);

    var list_frame = new Frame (null);
    list_frame.get_style_context ().add_class ("contact-list-frame");
    grid.attach (list_frame, 0, 1, 1, 1);

    var list_grid = new Grid ();
    list_grid.set_size_request (315, -1);
    list_grid.set_hexpand (false);
    list_frame.add (list_grid);
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
    scrolled.set_hexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.add (list);
    list_grid.add (scrolled);

    toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);
    list_grid.add (toolbar);

    var link_button = new ToolButton (null, C_("link-contacts-button", "Link"));
    link_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    link_button.is_important = true;
    link_button.sensitive = false;
    toolbar.add (link_button);
    link_button.clicked.connect ( (button) => {
	// TODO: Link selected_contact.individual into contact.individual
	// ensure we get the same individual so that the Contact is the same
	link_contacts.begin (contact, selected_contact, (obj, result) => {
	    link_contacts.end (result);
	    update_personas ();
	  });
      });

    list.selection_changed.connect ( (contact) => {
	selected_contact = contact;
	link_button.sensitive = contact != null;
      });

    label = new Label (_("Currently linked:"));
    label.set_valign (Align.CENTER);
    label.set_halign (Align.START);
    label.xalign = 0.0f;
    label.set_ellipsize (Pango.EllipsizeMode.END);
    grid.attach (label, 1, 0, 1, 1);

    var right_grid = new Grid ();
    right_grid.set_orientation (Orientation.VERTICAL);
    right_grid.set_border_width (10);
    right_grid.set_column_spacing (8);
    grid.attach (right_grid, 1, 1, 1, 1);

    persona_grid = new Grid ();
    persona_grid.set_orientation (Orientation.VERTICAL);
    persona_grid.set_row_spacing (8);
    right_grid.add (persona_grid);

    update_personas ();

    var size_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
    size_group.add_widget (right_grid);
    size_group.add_widget (list_grid);

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
