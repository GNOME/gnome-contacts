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
 * A {@link Chunk} that represents the birthday of a contact (similar to
 * {@link Folks.BirthdayDetails}}.
 */
public class Contacts.BirthdayChunk : Chunk {

  private DateTime? original_birthday = null;

  public DateTime? birthday {
    get { return this._birthday; }
    set {
      if (this.birthday == null && value == null)
        return;

      if (this.birthday != null && value != null && this.birthday.equal (value))
        return;

      bool was_empty = this.is_empty;
      bool was_dirty = this.dirty;
      this._birthday = (value != null)? value.to_utc () : null;
      notify_property ("birthday");
      if (was_empty != this.is_empty)
        notify_property ("is-empty");
      if (was_dirty != this.dirty)
        notify_property ("dirty");
    }
  }
  private DateTime? _birthday = null;

  public override string property_name { get { return "birthday"; } }

  public override bool is_empty { get { return this.birthday == null; } }

  public override bool dirty {
    get {
      if (this.birthday != null && this.original_birthday != null)
        return !this.birthday.equal (this.original_birthday);
      return this.birthday != this.original_birthday;
    }
  }

  construct {
    if (persona != null) {
      return_if_fail (persona is BirthdayDetails);
      persona.bind_property ("birthday", this, "birthday");
      this._birthday = ((BirthdayDetails) persona).birthday;
    }
    this.original_birthday = this.birthday;
  }

  public override Value? to_value () {
    return this.birthday;
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is BirthdayDetails) {
    yield ((BirthdayDetails) this.persona).change_birthday (this.birthday);
  }

  public bool is_today (DateTime now)
      requires (this.birthday != null) {
    int bd_m, bd_d, now_y, now_m, now_d;
    _birthday.to_local().get_ymd (null, out bd_m, out bd_d);
    now.get_ymd (out now_y, out now_m, out now_d);

    return (bd_m == now_m && bd_d == now_d)
      || (is_leap_day (bd_m, bd_d) && is_birthday_of_leap_day_in_non_leap_year (now_y, now_m, now_d));
  }

  // February 28th is treated as birthday on non-leap years.
  // This is consistent with the behaviour of evolution-data-server's Birthdays calendar:
  // https://gitlab.gnome.org/GNOME/evolution-data-server/-/issues/88
  private bool is_birthday_of_leap_day_in_non_leap_year (int now_y, int now_m, int now_d) {
    return now_m == 2 && now_d == 28 && !is_leap_year (now_y);
  }

  private bool is_leap_year (int year) {
    return ((DateYear) year).is_leap_year ();
  }

  private bool is_leap_day (int month, int day) {
    return month == 2 && day == 29;
  }
}
