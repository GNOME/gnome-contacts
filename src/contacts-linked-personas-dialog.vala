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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-linked-personas-dialog.ui")]
public class Contacts.LinkedPersonasDialog : Dialog {
  private const int AVATAR_SIZE = 54;

  [GtkChild]
  private ListBox linked_accounts_view;

  private Contact contact;

  public bool any_unlinked = false;

  public LinkedPersonasDialog (Window main_win, Contact contact) {
    Object (
      use_header_bar: 1,
      transient_for: main_win,
      title: contact.individual.display_name
    );

    this.contact = contact;
    this.linked_accounts_view.set_header_func (add_separator);

    // loading personas for display
    var personas = contact.get_personas_for_display ();
    bool is_first = true;
    foreach (var p in personas) {
      if (is_first) {
        is_first = false;
        continue;
      }

      var row_grid = new Grid ();

      var image_frame = new Avatar (AVATAR_SIZE, contact);
      image_frame.set_hexpand (false);
      image_frame.margin = 6;
      image_frame.margin_end = 12;
      row_grid.attach (image_frame, 0, 0, 1, 2);

      var display_name = new Label ("");
      display_name.set_halign (Align.START);
      display_name.set_valign (Align.END);
      display_name.set_hexpand (true);
      display_name.set_markup (Markup.printf_escaped ("<span font='bold'>%s</span>", p.display_id));

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

              this.any_unlinked = true;
              /* TODO: Support undo */
              /* TODO: Ensure we don't get suggestion for this linkage again */
            });
        });

      row_grid.show_all ();
      this.linked_accounts_view.add (row_grid);
    }
  }
}
