/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A {@link Chunk} that represents the postal addresses of a contact (similar
 * to {@link Folks.PostalAddressDetails}. Each element is a {@link Address}.
 */
public class Contacts.AddressesChunk : BinChunk {

  public override string property_name { get { return "postal-addresses"; } }

  public override string display_name { get { return _("Postal addresses"); } }

  public override string? icon_name { get { return "mark-location-symbolic"; } }

  construct {
    if (persona != null) {
      assert (persona is PostalAddressDetails);
      unowned var postal_address_details = (PostalAddressDetails) persona;

      foreach (var address_field in postal_address_details.postal_addresses) {
        var address = new Address.from_field_details (address_field);
        add_child (address);
      }
    }

    finish_initialization ();
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

  public PostalAddress address { get; construct; }

  public override bool is_empty {
    get { return this._is_empty; }
  }
  private bool _is_empty = true;

  public override string icon_name {
    get { return "mark-location-symbolic"; }
  }

  construct {
    update_on_address ();
    this.address.notify.connect ((obj, pspec) => { update_on_address (); });
  }

  public Address () {
    Object (address: new PostalAddress ("", "", "", "", "", "", "", "", ""));

    this.parameters = new Gee.HashMultiMap<string, string> ();
    this.parameters["type"] = "HOME";
  }

  public Address.from_field_details (PostalAddressFieldDetails address_field) {
    Object (address: address_field.value);

    this.parameters = address_field.parameters;
  }

  private void update_on_address () {
    if (this.is_empty != this.address.is_empty ()) {
      this._is_empty = this.address.is_empty ();
      notify_property ("is-empty");
    }
  }

  protected override int compare_internal (BinChunkChild other)
      requires (other is Address) {
    var this_types = this.parameters["type"];
    var other_types = other.parameters["type"];

    // Put home address first.
    // FIXME: we should be minding case sensitivity here
    if (("HOME" in this_types) != ("HOME" in other_types))
      return ("HOME" in this_types)? -1 : 1;

    // If no specific preference by type, compare by string
    unowned var other_address = (Address) other;
    var nr_cmp = strcmp (to_string (""), other_address.to_string (""));
    if (nr_cmp != 0)
      return nr_cmp;

    // Fall back to an even dumber comparison
    return dummy_compare_parameters (other);
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

  public override BinChunkChild copy () {
    var address = new Address ();
    address.address.address_format = this.address.address_format;
    address.address.country = this.address.country;
    address.address.extension = this.address.extension;
    address.address.locality = this.address.locality;
    address.address.po_box = this.address.po_box;
    address.address.postal_code = this.address.postal_code;
    address.address.region = this.address.region;
    address.address.street = this.address.street;
    copy_parameters (address);
    return address;
  }

  protected override Variant? to_gvariant_internal () {
    return new Variant ("(sssssssv)",
                        this.address.po_box,
                        this.address.extension,
                        this.address.street,
                        this.address.locality,
                        this.address.region,
                        this.address.postal_code,
                        this.address.country,
                        parameters_to_gvariant ());
  }

  public override void apply_gvariant (Variant variant)
      requires (variant.get_type ().equal (new VariantType ("(sssssssv)"))) {

    string po_box, extension, street, locality, region, postal_code, country;
    Variant params_variant;
    variant.get ("(sssssssv)",
                 out po_box,
                 out extension,
                 out street,
                 out locality,
                 out region,
                 out postal_code,
                 out country,
                 out params_variant);

    this.address.po_box = po_box;
    this.address.extension = extension;
    this.address.street = street;
    this.address.locality = locality;
    this.address.region = region;
    this.address.postal_code = postal_code;
    this.address.country = country;
    apply_gvariant_parameters (params_variant);
  }
}
