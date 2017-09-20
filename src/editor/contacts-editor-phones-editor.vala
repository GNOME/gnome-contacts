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

public class Contacts.Editor.PhonesEditor : CompositeEditor<PhoneDetails, PhoneFieldDetails> {

  public override string persona_property {
    get { return "phone-numbers"; }
  }

  public PhonesEditor (PhoneDetails? details = null) {
    if (details != null) {
      var phone_fields = Contact.sort_fields<PhoneFieldDetails>(details.phone_numbers);
      foreach (var phone_nr_detail in phone_fields)
        this.child_editors.add (new PhoneEditor (this, phone_nr_detail));
    } else {
      // No phones were passed on => make a single cell phone number
      this.child_editors.add (new PhoneEditor (this, null, "CELL"));
    }
  }

  public override async void save (PhoneDetails phone_details) throws PropertyError {
    yield phone_details.change_phone_numbers (aggregate_children ());
  }

  public class PhoneEditor : CompositeEditorChild<PhoneFieldDetails> {
    private TypeCombo type_combo;
    private Entry phone_entry;
    private Button delete_button;

    public PhoneEditor (PhonesEditor parent, PhoneFieldDetails? details = null, string? type = null) {
      this.type_combo = parent.create_type_combo (TypeSet.phone, details);
      string? phone_nr = (details != null)? details.value : null;
      this.phone_entry = parent.create_entry (phone_nr, _("Add number"));
      this.delete_button = parent.create_delete_button ();

      if (details != null && details.parameters != null)
        this.parameters = details.parameters;
      else
        this.parameters = new HashMultiMap<string, string> ();

      if (type != null)
        this.type_combo.set_to (type);
    }

    public override int attach_to_grid (Grid container_grid, int row) {
      container_grid.attach (this.type_combo, 0, row);
      container_grid.attach (this.phone_entry, 1, row);
      container_grid.attach (this.delete_button, 2, row);

      return 1;
    }

    public override PhoneFieldDetails create_details () {
      this.type_combo.update_type_parameter (this.parameters);
      return new PhoneFieldDetails (this.phone_entry.text, this.parameters);
    }
  }
}
