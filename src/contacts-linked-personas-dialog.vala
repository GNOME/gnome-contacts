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

using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-linked-personas-dialog.ui")]
public class Contacts.LinkedPersonasDialog : Gtk.Dialog {
  private const int AVATAR_SIZE = 54;

  [GtkChild]
  private Gtk.ListBox linked_accounts_view;

  private Individual individual;

  public bool any_unlinked = false;

  public LinkedPersonasDialog (Gtk.Window main_win, Store store, Individual individual) {
    Object (
      use_header_bar: 1,
      transient_for: main_win,
      title: individual.display_name
    );

    this.individual = individual;
    this.linked_accounts_view.set_header_func (add_separator);

    // loading personas for display
    var personas = Contacts.Utils.get_personas_for_display (individual);
    bool is_first = true;
    foreach (var p in personas) {
      if (is_first) {
        is_first = false;
        continue;
      }

      var row_grid = new Gtk.Grid ();

      var image_frame = new Avatar (AVATAR_SIZE, individual);
      image_frame.set_hexpand (false);
      image_frame.margin = 6;
      image_frame.margin_end = 12;
      row_grid.attach (image_frame, 0, 0, 1, 2);

      var display_name = new Gtk.Label ("");
      display_name.set_halign (Gtk.Align.START);
      display_name.set_valign (Gtk.Align.END);
      display_name.set_hexpand (true);
      display_name.set_markup (Markup.printf_escaped ("<span font='bold'>%s</span>", p.display_id));

      row_grid.attach (display_name, 1, 0, 1, 1);

      var store_name = new Gtk.Label (Contacts.Utils.format_persona_store_name_for_contact (p));
      store_name.set_halign (Gtk.Align.START);
      store_name.set_valign (Gtk.Align.START);
      store_name.set_hexpand (true);
      store_name.get_style_context ().add_class ("dim-label");
      row_grid.attach (store_name, 1, 1, 1, 1);

      var button = new Gtk.Button.with_label (_("Unlink"));
      button.margin_end = 6;
      button.set_valign (Gtk.Align.CENTER);
      button.get_child ().margin = 1;
      row_grid.attach (button, 2, 0, 1, 2);

      /* signal */
      button.clicked.connect (() => {
        // TODO: handly unlinking
        });

      row_grid.show_all ();
      this.linked_accounts_view.add (row_grid);
    }
  }
}
