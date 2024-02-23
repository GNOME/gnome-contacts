/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A {@link Chunk} that represents the associated URLs of a contact (similar to
 * {@link Folks.UrlDetails}. Each element is a {@link Contacts.Url}.
 */
public class Contacts.UrlsChunk : BinChunk {

  public override string property_name { get { return "urls"; } }

  public override string display_name { get { return _("URLs"); } }

  public override string? icon_name { get { return "website-symbolic"; } }

  construct {
    if (persona != null) {
      assert (persona is UrlDetails);
      unowned var url_details = (UrlDetails) persona;

      foreach (var url_field in url_details.urls) {
        var url = new Url.from_field_details (url_field);
        add_child (url);
      }
    }

    finish_initialization ();
  }

  protected override BinChunkChild create_empty_child () {
    return new Url ();
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is UrlDetails) {
    var afds = (Gee.Set<UrlFieldDetails>) get_abstract_field_details ();
    yield ((UrlDetails) this.persona).change_urls (afds);
  }
}

public class Contacts.Url : BinChunkChild {

  public string raw_url {
    get { return this._raw_url; }
    set { change_string_prop ("raw-url", ref this._raw_url, value); }
  }
  private string _raw_url = "";

  public override bool is_empty {
    get { return this.raw_url.strip () == ""; }
  }

  public override string icon_name {
    get { return "website-symbolic"; }
  }

  public Url () {
    this.parameters = new Gee.HashMultiMap<string, string> ();
    this.parameters["type"] = "PERSONAL";
  }

  public Url.from_field_details (UrlFieldDetails url_field) {
    this.raw_url = url_field.value;
    this.parameters = url_field.parameters;
  }

  protected override int compare_internal (BinChunkChild other)
      requires (other is Url) {
    return strcmp (this.raw_url, ((Url) other).raw_url);
  }

  /**
   * Tries to return an absolute URL (with a scheme).
   * Since we know contact URL values are for web addresses, we try to fall
   * back to https if there is no known scheme
   */
  public string get_absolute_url () {
    string scheme = Uri.parse_scheme (this.raw_url);
    return (scheme != null)? this.raw_url : "https://" + this.raw_url;
  }

  public override AbstractFieldDetails? create_afd () {
    if (this.is_empty)
      return null;

    return new UrlFieldDetails (this.raw_url, this.parameters);
  }

  public override BinChunkChild copy () {
    var url = new Url ();
    url.raw_url = this.raw_url;
    copy_parameters (url);
    return url;
  }

  protected override Variant? to_gvariant_internal () {
    return new Variant ("(sv)", this.raw_url, parameters_to_gvariant ());
  }

  public override void apply_gvariant (Variant variant)
      requires (variant.get_type ().equal (new VariantType ("(sv)"))) {

    string url;
    Variant params_variant;
    variant.get ("(sv)", out url, out params_variant);

    this.raw_url = url;
    apply_gvariant_parameters (params_variant);
  }
}
