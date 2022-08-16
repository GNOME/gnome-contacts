/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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

/**
 * A {@link Chunk} that represents the postal addresses of a contact (similar
 * to {@link Folks.PostalAddressDetails}}. Each element is a {@link Address}.
 */
public class Contacts.AddressesChunk : BinChunk {

  public override string property_name { get { return "postal-addresses"; } }

  construct {
    if (persona != null) {
      return_if_fail (persona is PostalAddressDetails);
      unowned var postal_address_details = (PostalAddressDetails) persona;

      foreach (var address_field in postal_address_details.postal_addresses) {
        var address = new Address.from_field_details (address_field);
        add_child (address);
      }
    }

    emptiness_check ();
  }

  protected override BinChunkChild create_empty_child () {
    return new Address ();
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is PostalAddressDetails) {
    var afds = (Gee.Set<PostalAddressFieldDetails>) get_abstract_field_details ();
    yield ((PostalAddressDetails) this.persona).change_postal_addresses (afds);
  }
}

public class Contacts.Address : BinChunkChild {

  public PostalAddress address {
    get { return this._address; }
    set {
      if (this._address.equal (value))
        return;

      bool was_empty = this._address.is_empty ();
      this._address = value;
      notify_property ("address");
      if (was_empty != value.is_empty ())
        notify_property ("is-empty");
    }
  }
  private PostalAddress _address = new PostalAddress ("", "", "", "", "", "", "", "", "");

  public override bool is_empty {
    get { return this.address.is_empty (); }
  }

  public override string icon_name {
    get { return "mark-location-symbolic"; }
  }

  public Address () {
    this.parameters = new Gee.HashMultiMap<string, string> ();
    this.parameters["type"] = "HOME";
  }

  public Address.from_field_details (PostalAddressFieldDetails address_field) {
    this.address = address_field.value;
    this.parameters = address_field.parameters;
  }

  /**
   * Returns the TypeDescriptor that describes the type of this address
   * (for example home, work, ...)
   */
  public TypeDescriptor get_address_type () {
    return TypeSet.general.lookup_by_parameters (this.parameters);
  }

  /**
   * Returns the address as a single string, with the several parts of
   * the address joined together with @parts_separator.
   */
  public string to_string (string parts_separator) {
    string[] lines = {};

    if (this.address.street != "")
      lines += this.address.street;
    if (this.address.extension != "")
      lines += this.address.extension;
    if (this.address.locality != "")
      lines += this.address.locality;
    if (this.address.region != "")
      lines += this.address.region;
    if (this.address.postal_code != "")
      lines += this.address.postal_code;
    if (this.address.po_box != "")
      lines += this.address.po_box;
    if (this.address.country != "")
      lines += this.address.country;
    if (this.address.address_format != "")
      lines += this.address.address_format;

    return string.joinv (parts_separator, lines);
  }

  /**
   * Returns the address as a "maps:q=..." URI, which can then be used
   * by supported apps to open up the specified location.
   */
  public string to_maps_uri () {
    var address_parts = to_string (" ");
    return "maps:q=%s".printf (GLib.Uri.escape_string (address_parts));
  }

  public override AbstractFieldDetails? create_afd () {
    if (this.is_empty)
      return null;

    return new PostalAddressFieldDetails (this.address, this.parameters);
  }
}
