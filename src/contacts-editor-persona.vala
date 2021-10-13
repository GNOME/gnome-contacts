/*
 * Copyright (C) 2019 Purism SPC
 * Author: Julian Sparber <julian.sparber@puri.sm>
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
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
 * A widget representing a persona in the {@link ContactEditor}.
 */
public class Contacts.EditorPersona : Gtk.Box {

  // List of important properties and a list of secoundary properties
  private const string[] PROPERTIES = {
    "email-addresses",
    "phone-numbers"
  };
  private const string[] OTHER_PROPERTIES = {
    "im-addresses",
    "urls",
    "nickname",
    "birthday",
    "postal-addresses",
    "notes"
  };

  private unowned Folks.Persona persona;
  private unowned Gtk.Box header;
  private unowned Gtk.Box content;

  private unowned Folks.IndividualAggregator aggregator;

  construct {
    var _header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    this.append (_header);
    this.header = _header;

    var listbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    this.content = listbox;
    this.content.add_css_class ("boxed-list");
    this.append (this.content);
  }

  public EditorPersona (Persona persona, IndividualAggregator aggregator) {
    Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
    this.persona = persona;
    this.aggregator = aggregator;
    create_label ();
    // TODO: implement the possibility f changing the addressbook of a persona

    // Add most important properites
    foreach (unowned var property in PROPERTIES) {
      debug ("Create property entry for %s", property);
      var prop_editor = new EditorProperty (persona, property);

      for (int i = 0; i < prop_editor.get_n_items (); i++) {
        var row = (EditorPropertyRow) prop_editor.get_item (i);
        row.show_with_animation (false);
        connect_row (row);
        this.content.append (row);
      }
    }

    // Add less important properties when the show_more button is clicked
    var show_more_button = new Gtk.Button ();
    var show_more_content = new Adw.ButtonContent ();
    show_more_content.icon_name = "view-more-symbolic";
    show_more_content.label = _("Show More");
    show_more_button.set_child (show_more_content);
    show_more_button.halign = Gtk.Align.CENTER;
    show_more_button.add_css_class ("flat");
    show_more_button.clicked.connect ((current_row) => {
      foreach (unowned string property in OTHER_PROPERTIES) {
        debug ("Create property entry for %s", property);
        var prop_editor = new EditorProperty (persona, property);

        for (int i = 0; i < prop_editor.get_n_items (); i++) {
          var row = (EditorPropertyRow) prop_editor.get_item (i);
          connect_row (row);
          this.content.append (row);
          row.show_with_animation ();
        }
      }
      this.content.remove (show_more_button);
    });
    this.content.append (show_more_button);
  }

  private void connect_row (EditorPropertyRow row) {
    row.notify["is-empty"].connect (() => {
      var empty_rows_count = this.count_empty_rows (row.ptype);
      if (row.is_empty) {
        // destroy all rows of our type which is not us
        this.destroy_empty_rows (row, row.ptype);
      }
      if (!row.is_empty && empty_rows_count == 0) {
        // We are sure that we only created one new row
        var new_rows = new EditorProperty (persona, row.ptype, true);
        if (new_rows.get_n_items () > 0) {
          var first_row = (EditorPropertyRow) new_rows.get_item (0);
          this.content.insert_child_after (first_row, row);
          connect_row (first_row);
        } else {
          debug ("Couldn't add new row with type %s", row.ptype);
        }
      }
    });
  }

  private uint count_empty_rows (string type) {
    uint count = 0;
    for (unowned Gtk.Widget? child = this.content.get_first_child ();
         child != null;
         child = child.get_next_sibling ()) {
      unowned var prop = (child as EditorPropertyRow);
      if (prop != null && !prop.is_removed && prop.is_empty && prop.ptype == type) {
        count++;
      }
    }
    return count;
  }

  private void destroy_empty_rows (Gtk.Widget current_row, string type) {
    for (unowned Gtk.Widget? child = this.content.get_first_child ();
         child != null;
         child = child.get_next_sibling ()) {
      if (current_row == child)
        continue;

      unowned var prop = (child as EditorPropertyRow);
      if (prop != null && !prop.is_removed && prop.is_empty && prop.ptype == type) {
        prop.remove ();
      }
    }
  }

  private void create_label () {
    string title = "";
    unowned var fake_persona = this.persona as FakePersona;
    if (fake_persona != null && fake_persona.real_persona != null) {
      title = fake_persona.real_persona.store.display_name;
    } else {
      title = this.aggregator.primary_store.display_name;
    }

    Gtk.Label addressbook = new Gtk.Label (title);
    addressbook.add_css_class ("heading");
    this.header.append (addressbook);
  }
}
