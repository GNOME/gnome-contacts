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

public class Contacts.Editor.FullNameEditor : DetailsEditor<NameDetails> {

  private Entry name_entry;

  public override string persona_property {
    get { return "full-name"; }
  }

  public FullNameEditor (Contact? contact = null, NameDetails? details = null) {
    string? name = (contact != null)? contact.individual.display_name : null;
    this.name_entry = create_entry (name, _("Add name"));
    this.name_entry.valign = Align.CENTER;
  }

  public override int attach_to_grid (Grid container_grid, int row) {
    container_grid.attach (this.name_entry, 1, row, 2, 3);
    return 0;
  }

  public override async void save (NameDetails name_details) throws PropertyError {
	yield name_details.change_full_name (this.name_entry.text);
  }

  public override Value create_value () {
    Value v = Value (typeof (string));
    v.set_string (this.name_entry.text);
    return v;
  }
}
