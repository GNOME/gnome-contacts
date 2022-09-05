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
 * A {@link Chunk} that represents the internet messaging (IM) addresses of a
 * contact (similar to {@link Folks.ImDetails}}. Each element is a
 * {@link ImAddress}.
 */
public class Contacts.ImAddressesChunk : BinChunk {

  public override string property_name { get { return "im-addresses"; } }

  construct {
    if (persona != null) {
      return_if_fail (persona is ImDetails);
      unowned var im_details = (ImDetails) persona;

      var iter = im_details.im_addresses.map_iterator ();
      while (iter.next ()) {
        var protocol = iter.get_key ();
        var im = new ImAddress.from_field_details (iter.get_value (), protocol);
        add_child (im);
      }
    }

    emptiness_check ();
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

  public override AbstractFieldDetails? create_afd () {
    if (this.is_empty)
      return null;

    return new ImFieldDetails (this.address, this.parameters);
  }
}