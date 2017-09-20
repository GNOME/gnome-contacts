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

public class Contacts.Editor.BirthdayEditor : DetailsEditor<BirthdayDetails> {
  private Label label;

  private Grid date_grid;
  private SpinButton day_spin;
  private ComboBoxText month_combo;
  private SpinButton year_spin;

  private Button delete_button;

  public override string persona_property {
    get { return "birthday"; }
  }

  /**
   * The day of the month (ranging from 1 to 31, depending on the month)
   */
  private int day {
    get { return this.day_spin.get_value_as_int (); }
    set { this.day_spin.set_value (value); }
  }

  /**
   * The month (ranging from 1 to 12)
   */
  private int month {
    get { return this.month_combo.get_active (); }
    set { this.month_combo.set_active (value - 1); }
  }

  /**
   * The year
   */
  private int year {
    get { return this.year_spin.get_value_as_int (); }
    set { this.year_spin.set_value (value); }
  }

  public BirthdayEditor (BirthdayDetails? details = null) {
    DateTime date;
    if (details != null && details.birthday != null)
      date = details.birthday.to_local ();
    else
      date = new DateTime.now_local ();

    this.label = create_label (_("Birthday"));
    this.date_grid = create_date_widget (date);
    this.delete_button = create_delete_button ();

    this.day = date.get_day_of_month ();
    this.month = date.get_month ();
    this.year = date.get_year ();
    set_day_spin_range ();

    // Now that we've set the date for first time, listen to changes
    this.day_spin.changed.connect ( () => { this.dirty = true; });
    this.month_combo.changed.connect ( () => {
        this.dirty = true;
        set_day_spin_range ();
      });
    this.year_spin.changed.connect ( () => {
        this.dirty = true;
        set_day_spin_range ();
      });
  }

  public override int attach_to_grid (Grid container_grid, int row) {
    container_grid.attach (this.label, 0, row);
    container_grid.attach (this.date_grid, 1, row);
    container_grid.attach (this.delete_button, 2, row);

    return 1;
  }

  public override async void save (BirthdayDetails birthday_details) throws PropertyError {
    yield birthday_details.change_birthday (create_datetime ().to_utc ());
  }

  public override Value create_value () {
    var result = Value (typeof (DateTime));
    result.set_boxed (create_datetime ().to_utc ());
    return result;
  }

  private DateTime create_datetime () {
    return new DateTime.local (this.year, this.month + 1, this.day, 0, 0, 0);
  }

  private Grid create_date_widget (DateTime? date) {
    var date_grid = new Grid ();
    date_grid.column_spacing = 12;

    // Day
    this.day_spin = new SpinButton.with_range (1.0, 31.0, 1.0);
    this.day_spin.digits = 0;
    this.day_spin.numeric = true;
    date_grid.add (day_spin);

    // Month
    this.month_combo = new ComboBoxText ();
    var january = new DateTime.local (1, 1, 1, 1, 1, 1);
    for (int i = 0; i < 12; i++) {
        var month = january.add_months (i);
        this.month_combo.append_text (month.format ("%B"));
    }
    this.month_combo.get_style_context ().add_class ("contacts-combo");
    this.month_combo.hexpand = true;
    date_grid.add (month_combo);

    // Year
    this.year_spin = new SpinButton.with_range (1800, 3000, 1);
    this.year_spin.digits = 0;
    this.year_spin.numeric = true;
    date_grid.add (year_spin);

    date_grid.show_all ();
    return date_grid;
  }

  private void set_day_spin_range () {
    var days_in_month = Date.get_days_in_month ((DateMonth) this.month, (DateYear) this.year);
    this.day_spin.set_range (1, days_in_month);
  }
}
