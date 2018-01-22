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
  private const int AVATAR_SIZE = 54;

  Contact contact;
  ListBox linked_accounts_view;

  public bool any_unlinked;

  public LinkedAccountsDialog (Window main_win, Contact contact) {
    Object (
      use_header_bar: 1,
      transient_for: main_win,
      modal: true
    );

    this.contact = contact;
    any_unlinked = false;

    var headerbar = get_header_bar () as Gtk.HeaderBar;
    headerbar.set_title (_("%s").printf (contact.individual.display_name));
    headerbar.set_subtitle (_("Linked Accounts"));

    set_default_size (600, 400);

    var grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_row_spacing (12);
    grid.set_border_width (8);

    var scrolled = new Gtk.ScrolledWindow (null, null);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_hexpand (true);
    scrolled.set_vexpand (true);
    scrolled.set_shadow_type (ShadowType.IN);

    linked_accounts_view = new ListBox ();
    linked_accounts_view.set_selection_mode (SelectionMode.NONE);
    linked_accounts_view.set_header_func (add_separator);

    scrolled.add (linked_accounts_view);
    grid.add (scrolled);

    var label = new Label (_("You can link contacts by selecting them from the contacts list"));
    label.set_halign (Align.CENTER);
    grid.add (label);

    grid.show_all ();
    (get_content_area () as Container).add (grid);

    /* loading personas for display */
    var personas = contact.get_personas_for_display ();
    /* Cause personas are sorted properly I can do this */
    bool is_first = true;
    foreach (var p in personas) {
      if (is_first) {
	is_first = false;
	continue;
      }

      var row_grid = new Grid ();

      var image_frame = new Avatar (AVATAR_SIZE);
      image_frame.set_hexpand (false);
      image_frame.margin = 6;
      image_frame.margin_end = 12;
      contact.keep_widget_uptodate (image_frame, (w) => {
          (w as Avatar).set_image.begin (contact.individual, contact);
        });
      row_grid.attach (image_frame, 0, 0, 1, 2);

      var display_name = new Label ("");
      display_name.set_halign (Align.START);
      display_name.set_valign (Align.END);
      display_name.set_hexpand (true);
      display_name.set_markup (Markup.printf_escaped ("<span font='bold'>%s</span>",
						      p.display_id));

      row_grid.attach (display_name, 1, 0, 1, 1);

      var store_name = new Label (Contact.format_persona_store_name_for_contact (p));
      store_name.set_halign (Align.START);
      store_name.set_valign (Align.START);
      store_name.set_hexpand (true);
      store_name.get_style_context ().add_class ("dim-label");
      row_grid.attach (store_name, 1, 1, 1, 1);

      var button = new Button.with_label (_("Unlink"));
      button.margin_end = 6;
      button.set_valign (Align.CENTER);
      button.get_child ().margin = 1;
      row_grid.attach (button, 2, 0, 1, 2);

      /* signal */
      button.clicked.connect (() => {
	  unlink_persona.begin (contact, p, (obj, result) => {
	      unlink_persona.end (result);

	      row_grid.destroy ();

	      any_unlinked = true;
	      /* TODO: Support undo */
	      /* TODO: Ensure we don't get suggestion for this linkage again */
	    });
	});

      row_grid.show_all ();
      linked_accounts_view.add (row_grid);
    }
  }
}
