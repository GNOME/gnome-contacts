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

public class Contacts.Editor.AddressesEditor : CompositeEditor<PostalAddressDetails, PostalAddressFieldDetails> {

  public override string persona_property {
    get { return "postal-addresses"; }
  }

  public AddressesEditor (PostalAddressDetails? details = null) {
    if (details != null) {
      var address_fields = Contact.sort_fields<PostalAddressFieldDetails>(details.postal_addresses);
      foreach (var address_field_detail in address_fields)
        this.child_editors.add (new AddressEditor (this, address_field_detail));
    } else {
      // No addresss were passed on => make a blank home address
      this.child_editors.add (new AddressEditor (this, null, "HOME"));
    }
  }

  public override async void save (PostalAddressDetails address_details) throws PropertyError {
    yield address_details.change_postal_addresses (aggregate_children ());
  }

  public class AddressEditor : CompositeEditorChild<PostalAddressFieldDetails> {
    private TypeCombo type_combo;
    private Box address_widget;
    private Button delete_button;

    public Entry? entries[7];  /* must be the number of elements in postal_element_props */
    public const string[] POSTAL_ELEMENT_PROPS = {"street", "extension", "locality", "region", "postal_code", "po_box", "country"};
    public static string[] POSTAL_ELEMENT_NAMES = {_("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

    public AddressEditor (AddressesEditor parent, PostalAddressFieldDetails? details = null, string? type = null) {
      this.type_combo = parent.create_type_combo (TypeSet.general, details);
      this.type_combo.valign = Gtk.Align.START;
      this.address_widget = create_address_widget (parent);
      this.delete_button = parent.create_delete_button ();
      this.delete_button.valign = Gtk.Align.START;

      if (details != null && details.value != null) {
          var address = details.value;
          this.entries[0].text = address.street ?? "";
          this.entries[1].text = address.extension ?? "";
          this.entries[2].text = address.locality ?? "";
          this.entries[3].text = address.region ?? "";
          this.entries[4].text = address.postal_code ?? "";
          this.entries[5].text = address.po_box ?? "";
          this.entries[6].text = address.country ?? "";
      }
      if (type != null)
        this.type_combo.set_to (type);
    }

    public override int attach_to_grid (Grid container_grid, int row) {
      container_grid.attach (this.type_combo, 0, row);
      container_grid.attach (this.address_widget, 1, row);
      container_grid.attach (this.delete_button, 2, row);

      return 1;
    }

    public override PostalAddressFieldDetails create_details () {
      var address = new PostalAddress (
          this.entries[5].text, // po_box
          this.entries[1].text, // extension
          this.entries[0].text, // street
          this.entries[2].text, // locality
          this.entries[3].text, // region
          this.entries[4].text, // postal_code
          this.entries[6].text, // country
          "derp?", // XXX
          "");
      // XXX parameters
      return new PostalAddressFieldDetails (address, null);
    }

    private Box create_address_widget (AddressesEditor parent) {
      var address_box = new Box(Orientation.VERTICAL, 0);
      address_box.hexpand = true;
      address_box.show ();

      for (int i = 0; i < entries.length; i++) {
        string? postal_part = null;
        /* details.value.get (POSTAL_ELEMENT_PROPS[i], out postal_part); */

        entries[i] = parent.create_entry (postal_part, POSTAL_ELEMENT_NAMES[i]);
        entries[i].get_style_context ().add_class ("contacts-entry");
        entries[i].get_style_context ().add_class ("contacts-postal-entry");
        address_box.add (entries[i]);
      }

      return address_box;
    }
  }
}
