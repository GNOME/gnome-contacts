/*
 * Copyright (C) 2019 Purism SPC
 * Author: Julian Sparber <julian.sparber@puri.sm>
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
  private const GLib.ActionEntry[] action_entries = {
    { "change-addressbook", change_addressbook },
  };

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

  private Folks.Persona persona;
  private Gtk.Box header;
  private Gtk.ListBox content;

  private Folks.IndividualAggregator aggregator;

  construct {
    this.header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    add (this.header);

    var frame = new Gtk.Frame (null);
    this.content = new Gtk.ListBox ();
    this.content.set_header_func (list_box_update_header_func);
    frame.add (this.content);
    add (frame);

    SimpleActionGroup actions = new SimpleActionGroup ();
    actions.add_action_entries (action_entries, this);
    this.insert_action_group ("persona", actions);
  }

  private void list_box_update_header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
    if (before == null) {
      row.set_header (null);
      return;
    }

    if (row.get_header () == null) {
      var header = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
      header.show ();
      row.set_header (header);
    }
  }

  public EditorPersona (Persona persona, IndividualAggregator aggregator) {
    Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
    this.persona = persona;
    this.aggregator = aggregator;
    create_label ();
    /* TODO: implement the possibility of changing the addressbook of a persona
    create_button (); */

    // Add most important properites
    foreach (var property in PROPERTIES) {
      debug ("Create property entry for %s", property);
      var rows = new EditorProperty (persona, property);
      foreach (var row in rows) {
        row.show_with_animation (false);
        connect_row (row);
        this.content.add (row);
      }
    }
    // Add a row with a button to show all properties
    Gtk.ListBoxRow show_all_row = new Gtk.ListBoxRow ();
    show_all_row.set_selectable (false);
    // Add less important property when the show_more button is clicked
    this.content.row_activated.connect ((current_row) => {
      if (current_row == show_all_row) {
        foreach (var property in OTHER_PROPERTIES) {
          debug ("Create property entry for %s", property);
          var rows = new EditorProperty (persona, property);
          foreach (var row in rows) {
            connect_row (row);
            this.content.add (row);
            row.show_with_animation ();
          }
        }
        show_all_row.destroy ();
      }
    });
    Gtk.Image show_all = new Gtk.Image.from_icon_name ("view-more-symbolic",
                                                       Gtk.IconSize.BUTTON);
    show_all.margin = 12;
    show_all_row.add (show_all);
    this.content.add (show_all_row);
  }

  private void connect_row (EditorPropertyRow row) {
    row.notify["is-empty"].connect ( () => {
      var empty_rows_count = this.count_empty_rows (row.ptype);
      if (row.is_empty) {
        // destroy all rows of our type which is not us
        this.destroy_empty_rows (row, row.ptype);
      }
      if (!row.is_empty && empty_rows_count == 0) {
        // We are sure that we only created one new row
        var new_rows = new EditorProperty (persona, row.ptype, true);
        if (new_rows.size > 0) {
          this.content.insert (new_rows[0], row.get_index () + 1);
          connect_row (new_rows[0]);
          new_rows[0].show_with_animation ();
        } else {
          debug ("Couldn't add new row with type %s", row.ptype);
        }
      }
    });
  }

  private uint count_empty_rows (string type) {
    uint count = 0;
    foreach (var row in this.content.get_children ()) {
      var prop = (row as EditorPropertyRow);
      if (prop != null && !prop.is_removed && prop.is_empty && prop.ptype == type) {
        count++;
      }
    }
    return count;
  }

  private void destroy_empty_rows (Gtk.ListBoxRow current_row, string type) {
    foreach (var row in this.content.get_children ()) {
      if (current_row != row) {
        var prop = (row as EditorPropertyRow);
        if (prop != null && !prop.is_removed && prop.is_empty && prop.ptype == type) {
          prop.remove ();
        }
      }
    }
  }

  private void change_addressbook () {
    /* Not yet implemented */
  }

  private void create_label () {
    string title = "";
    FakePersona fake_persona = this.persona as FakePersona;
    if (fake_persona != null && fake_persona.real_persona != null) {
      title = fake_persona.real_persona.store.display_name;
    } else {
      title = this.aggregator.primary_store.display_name;
    }

    Gtk.Label addressbook = new Gtk.Label (title);
    this.header.pack_start (addressbook, false, false, 0);
  }

  private void create_button () {
    var image = new Gtk.Image.from_icon_name ("emblem-system-symbolic",
                                              Gtk.IconSize.BUTTON);
    var button = new Gtk.MenuButton ();
    button.set_image (image);
    var builder = new Gtk.Builder.from_resource ("/org/gnome/Contacts/ui/contacts-editor-menu.ui");
    var menu = builder.get_object ("editor_menu") as Gtk.Widget;
    button.set_popover (menu);
    this.header.pack_end (button, false, false, 0);
  }
}
