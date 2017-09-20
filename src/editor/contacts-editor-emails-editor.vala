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

public class Contacts.Editor.EmailsEditor : CompositeEditor<EmailDetails, EmailFieldDetails> {

  public override string persona_property {
    get { return "email-addresses"; }
  }

  public EmailsEditor (EmailDetails? details = null) {
    if (details != null) {
      var email_fields = Contact.sort_fields<EmailFieldDetails>(details.email_addresses);
      foreach (var email_field_detail in email_fields)
        this.child_editors.add (new EmailEditor (this, email_field_detail));
    } else {
      // No emails were passed on => make a single personal email address
      this.child_editors.add (new EmailEditor (this, null, "PERSONAL"));
    }
  }

  public override async void save (EmailDetails email_details) throws PropertyError {
    yield email_details.change_email_addresses (aggregate_children ());
  }

  /**
   * Deals with a single email address field.
   */
  public class EmailEditor : CompositeEditorChild<EmailFieldDetails> {
    private TypeCombo type_combo;
    private Entry email_entry;
    private Button delete_button;

    public EmailEditor (EmailsEditor parent, EmailFieldDetails? details = null, string? type = null) {
      this.type_combo = parent.create_type_combo (TypeSet.email, details);
      string? email = (details != null)? details.value : null;
      this.email_entry = parent.create_entry (email, _("Add email"));
      this.delete_button = parent.create_delete_button ();

      if (type != null)
        this.type_combo.set_to (type);
    }

    public override int attach_to_grid (Grid container_grid, int row) {
      container_grid.attach (this.type_combo, 0, row);
      container_grid.attach (this.email_entry, 1, row);
      container_grid.attach (this.delete_button, 2, row);

      return 1;
    }

    public override EmailFieldDetails create_details () {
      // XXX parameters
      return new EmailFieldDetails (this.email_entry.text, null);
    }
  }
}
