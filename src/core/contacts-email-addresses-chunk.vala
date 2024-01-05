/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

public class Contacts.EmailAddressesChunk : BinChunk {

  public override string property_name { get { return "email-addresses"; } }

  public override string display_name { get { return _("Email addresses"); } }

  public override string? icon_name { get { return "mail-unread-symbolic"; } }

  construct {
    if (persona != null) {
      assert (persona is EmailDetails);
      unowned var email_details = (EmailDetails) persona;

      foreach (var email_field in email_details.email_addresses) {
        var email = new EmailAddress.from_field_details (email_field);
        add_child (email);
      }
    }

    finish_initialization ();
  }

  protected override BinChunkChild create_empty_child () {
    return new EmailAddress ();
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is EmailDetails) {
    var afds = (Gee.Set<EmailFieldDetails>) get_abstract_field_details ();
    yield ((EmailDetails) this.persona).change_email_addresses (afds);
  }
}

public class Contacts.EmailAddress : BinChunkChild {

  public string raw_address {
    get { return this._raw_address; }
    set { change_string_prop ("raw-address", ref this._raw_address, value); }
  }
  private string _raw_address = "";

  public override bool is_empty {
    get { return this.raw_address.strip () == ""; }
  }

  public override string icon_name {
    get { return "mail-unread-symbolic"; }
  }

  public EmailAddress () {
    this.parameters = new Gee.HashMultiMap<string, string> ();
    this.parameters["type"] = "PERSONAL";
  }

  public EmailAddress.from_field_details (EmailFieldDetails email_field) {
    this.raw_address = email_field.value;
    this.parameters = email_field.parameters;
  }

  protected override int compare_internal (BinChunkChild other)
      requires (other is EmailAddress) {
    unowned var other_email_addr = (EmailAddress) other;
    var addr_cmp = strcmp (this.raw_address, other_email_addr.raw_address);
    if (addr_cmp != 0)
      return addr_cmp;
    return dummy_compare_parameters (other);
  }

  /**
   * Returns the TypeDescriptor that describes the type of the email address
   * (for example personal, work, ...)
   */
  public TypeDescriptor get_email_address_type () {
    return TypeSet.email.lookup_by_parameters (this.parameters);
  }

  public override AbstractFieldDetails? create_afd () {
    if (this.is_empty)
      return null;

    return new EmailFieldDetails (this.raw_address, this.parameters);
  }
  public override BinChunkChild copy () {
    var email_address = new EmailAddress ();
    email_address.raw_address = this.raw_address;
    copy_parameters (email_address);
    return email_address;
  }

  protected override Variant? to_gvariant_internal () {
    return new Variant ("(sv)", this.raw_address, parameters_to_gvariant ());
  }

  public override void apply_gvariant (Variant variant)
      requires (variant.get_type ().equal (new VariantType ("(sv)"))) {

    string email_addr;
    Variant params_variant;
    variant.get ("(sv)", out email_addr, out params_variant);

    this.raw_address = email_addr;
    apply_gvariant_parameters (params_variant);
  }

  public string get_mailto_uri () {
    return "mailto:" + Uri.escape_string (this.raw_address, "@" , false);
  }
}
