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
 * A {@link Chunk} that represents the phone numbers of a contact (similar to
 * {@link Folks.PhoneDetails}}. Each element is a {@link Phone}.
 */
public class Contacts.PhonesChunk : BinChunk {

  public override string property_name { get { return "phone-numbers"; } }

  construct {
    if (persona != null) {
      return_if_fail (persona is PhoneDetails);
      unowned var phone_details = (PhoneDetails) persona;

      foreach (var phone_field in phone_details.phone_numbers) {
        var phone = new Phone.from_field_details (phone_field);
        add_child (phone);
      }
    }

    finish_initialization ();
  }

  protected override BinChunkChild create_empty_child () {
    return new Phone ();
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is PhoneDetails) {
    var afds = (Gee.Set<PhoneFieldDetails>) get_abstract_field_details ();
    yield ((PhoneDetails) this.persona).change_phone_numbers (afds);
  }
}

public class Contacts.Phone : BinChunkChild {

  /**
   * The "raw" phone number as inputted by a user or from a contact. It may or
   * may not be an actual valid phone number.
   */
  public string raw_number {
    get { return this._raw_number; }
    set { change_string_prop ("raw-number", ref this._raw_number, value); }
  }
  private string _raw_number = "";

  public override bool is_empty {
    get { return this.raw_number.strip () == ""; }
  }

  public override string icon_name {
    get { return "phone-symbolic"; }
  }

  public Phone () {
    this.parameters = new Gee.HashMultiMap<string, string> ();
    this.parameters["type"] = "CELL";
  }

  public Phone.from_field_details (PhoneFieldDetails phone_field) {
    this.raw_number = phone_field.value;
    this.parameters = phone_field.parameters;
  }

  protected override int compare_internal (BinChunkChild other)
      requires (other is Phone) {
    unowned var other_phone = (Phone) other;
    var nr_cmp = strcmp (this.raw_number, other_phone.raw_number);
    if (nr_cmp != 0)
      return nr_cmp;
    return dummy_compare_parameters (other);
  }

  /**
   * Returns the TypeDescriptor that describes the type of phone number
   * (for example mobile, work, fax, ...)
   */
  public TypeDescriptor get_phone_type () {
    return TypeSet.phone.lookup_by_parameters (this.parameters);
  }

  public override AbstractFieldDetails? create_afd () {
    if (this.is_empty)
      return null;

    return new PhoneFieldDetails (this.raw_number, this.parameters);
  }

  public override BinChunkChild copy () {
    var phone = new Phone ();
    phone.raw_number = this.raw_number;
    copy_parameters (phone);
    return phone;
  }
}
