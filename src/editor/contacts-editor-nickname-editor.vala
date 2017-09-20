/*
 * Copyright (C) 2017 Niels De Graef <nielsdegraef@gmail.com>
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
using Gee;
using Gtk;

public class Contacts.Editor.NicknameEditor : DetailsEditor<NameDetails> {
  private Label label;
  private Entry nickname_entry;
  private Button delete_button;

  public override string persona_property {
    get { return "nickname"; }
  }

  public NicknameEditor (NameDetails? details = null) {
    this.label = create_label (_("Nickname"));
    string? nickname = (details != null)? details.nickname : null;
    this.nickname_entry = create_entry (nickname);
    this.delete_button = create_delete_button ();
  }

  public override int attach_to_grid (Grid container_grid, int row) {
    container_grid.attach (this.label, 0, row);
    container_grid.attach (this.nickname_entry, 1, row);
    container_grid.attach (this.delete_button, 2, row);

    return 1;
  }

  public override async void save (NameDetails name_details) throws PropertyError {
    yield name_details.change_nickname (this.nickname_entry.text);
  }

  public override Value create_value () {
    var result = Value (typeof (string));
    result.set_string (nickname_entry.text);
    return result;
  }
}
