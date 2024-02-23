/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A {@link Chunk} that represents the internet messaging (IM) addresses of a
 * contact (similar to {@link Folks.ImDetails}. Each element is a
 * {@link ImAddress}.
 */
public class Contacts.ImAddressesChunk : BinChunk {

  public override string property_name { get { return "im-addresses"; } }

  public override string display_name { get { return _("Instant Messaging addresses"); } }

  public override string? icon_name { get { return "chat-symbolic"; } }

  construct {
    if (persona != null) {
      assert (persona is ImDetails);
      unowned var im_details = (ImDetails) persona;

      var iter = im_details.im_addresses.map_iterator ();
      while (iter.next ()) {
        var protocol = iter.get_key ();
        var im = new ImAddress.from_field_details (iter.get_value (), protocol);
        add_child (im);
      }
    }

    finish_initialization ();
  }

  protected override BinChunkChild create_empty_child () {
    return new ImAddress ();
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is ImDetails) {
    // We can't use get_abstract_field_details() here, since we need the
    // protocol as well, and to use a Gee.MultiMap for it
    var afds = new Gee.HashMultiMap<string, ImFieldDetails> ();
    for (uint i = 0; i < get_n_items (); i++) {
      var im_addr = (ImAddress) get_item (i);
      var afd = (ImFieldDetails) im_addr.create_afd ();
      if (afd != null)
        afds[im_addr.protocol] = afd;
    }

    yield ((ImDetails) this.persona).change_im_addresses (afds);
  }
}

public class Contacts.ImAddress : BinChunkChild {

  public string protocol { get; private set; default = ""; }

  public string address {
    get { return this._address; }
    set { change_string_prop ("address", ref this._address, value); }
  }
  private string _address = "";

  public override bool is_empty {
    get { return this.address.strip () == ""; }
  }

  public override string icon_name {
    get { return "chat-symbolic"; }
  }

  public ImAddress () {
    this.parameters = new Gee.HashMultiMap<string, string> ();
  }

  public ImAddress.from_field_details (ImFieldDetails im_field, string protocol) {
    this.address = im_field.value;
    this.protocol = protocol;
    this.parameters = im_field.parameters;
  }

  protected override int compare_internal (BinChunkChild other)
      requires (other is ImAddress) {
    unowned var other_im_addr = (ImAddress) other;

    var protocol_cmp = strcmp (this.protocol, other_im_addr.protocol);
    if (protocol_cmp != 0)
      return protocol_cmp;

    var addr_cmp = strcmp (this.address, other_im_addr.address);
    if (addr_cmp != 0)
      return addr_cmp;

    return dummy_compare_parameters (other);
  }

  public override AbstractFieldDetails? create_afd () {
    if (this.is_empty)
      return null;

    return new ImFieldDetails (this.address, this.parameters);
  }

  public override BinChunkChild copy () {
    var ima = new ImAddress ();
    ima.protocol = this.protocol;
    ima.address = this.address;
    copy_parameters (ima);
    return ima;
  }

  protected override Variant? to_gvariant_internal () {
    return new Variant ("(ssv)",
                        this.protocol,
                        this.address,
                        parameters_to_gvariant ());
  }

  public override void apply_gvariant (Variant variant)
      requires (variant.get_type ().equal (new VariantType ("(ssv)"))) {

    string protocol, address;
    Variant params_variant;
    variant.get ("(ssv)", out protocol, out address, out params_variant);

    this.protocol = protocol;
    this.address = address;
    apply_gvariant_parameters (params_variant);
  }
}
