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

public class Contacts.LinkedAccountsDialog : Dialog {
  private Contact contact;
  private Egg.ListBox linked_accounts_view;

  public LinkedAccountsDialog (Contact contact) {
    this.contact = contact;
    set_title (_("%s - Linked Accounts").printf (contact.display_name));
    set_transient_for (App.app.window);
    set_modal (true);
    set_default_size (600, 400);

    add_buttons (_("Close"), ResponseType.CLOSE, null);

    var grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_row_spacing (12);
    grid.set_border_width (8);

    var scrolled = new Gtk.ScrolledWindow (null, null);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_hexpand (true);
    scrolled.set_vexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);

    linked_accounts_view = new Egg.ListBox ();
    linked_accounts_view.set_selection_mode (SelectionMode.NONE);

    linked_accounts_view.add_to_scrolled (scrolled);
    grid.add (scrolled);

    var label = new Label (_("You can manually link contacts from the contacts list"));
    label.set_halign (Align.CENTER);
    grid.add (label);

    grid.show_all ();
    (get_content_area () as Container).add (grid);

    /* loading personas for display */
    var personas = contact.get_personas_for_display ();
    /* Cause personas are sorted properly I can do this */
    bool is_first = true;
    int counter = 1;
    foreach (var p in personas) {
      if (is_first) {
	is_first = false;
	continue;
      }

      var row_grid = new Grid ();
      row_grid.set_row_spacing (6);

      var image_frame = new ContactFrame (Contact.SMALL_AVATAR_SIZE);
      image_frame.set_hexpand (false);
      image_frame.margin = 6;
      image_frame.margin_right = 12;
      contact.keep_widget_uptodate (image_frame,  (w) => {
	  (w as ContactFrame).set_image (contact.individual, contact);
	});
      row_grid.attach (image_frame, 0, 0, 1, 2);

      var display_name = new Label ("");
      display_name.set_halign (Align.START);
      display_name.set_valign (Align.END);
      display_name.set_hexpand (true);
      display_name.set_markup (Markup.printf_escaped ("<span font='12px bold'>%s</span>",
						      p.display_id));

      row_grid.attach (display_name, 1, 0, 1, 1);

      var store_name = new Label (Contact.format_persona_store_name_for_contact (p));
      store_name.set_halign (Align.START);
      store_name.set_valign (Align.START);
      store_name.set_hexpand (true);
      store_name.get_style_context ().add_class ("dim-label");
      row_grid.attach (store_name, 1, 1, 1, 1);

      var button = new Button.with_label (_("Remove"));
      button.margin = 6;
      button.margin_left = 12;
      button.set_valign (Align.CENTER);
      button.get_child ().margin = 6;
      row_grid.attach (button, 2, 0, 1, 2);

      /* signal */
      button.clicked.connect (() => {
	  unlink_persona.begin (contact, p, (obj, result) => {
	      unlink_persona.end (result);
	      var sep = row_grid.get_data<Widget> ("separator");
	      if (sep != null)
		sep.destroy ();

	      row_grid.destroy ();
	      /* TODO: Support undo */
	      /* TODO: Ensure we don't get suggestion for this linkage again */
	    });
	});

      row_grid.show_all ();
      linked_accounts_view.add (row_grid);

      if (counter != personas.size - 1) {
	var sep = new Separator (Orientation.HORIZONTAL);
	linked_accounts_view.add (sep);
	counter++;
	row_grid.set_data ("separator", sep);
      }
    }

    /* signals */
    response.connect ( (response_id) => {
	this.destroy ();
      });
  }
}
