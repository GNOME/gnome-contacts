/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 * Copyright (C) 2019 Purism SPC
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

using Gtk;
using Folks;
using Gee;

/**
 * A widget that allows the user to edit a given {@link Contact}.
 */
public class Contacts.ContactEditor : Box {
  private Individual individual;
  private Entry name_entry;
  private AvatarSelector avatar_selector = null;
  private Avatar avatar;

  public ContactEditor (Individual individual, IndividualAggregator aggregator) {
    Object (orientation: Orientation.VERTICAL, spacing: 24);
    this.individual = individual;

    Box header = new Box (Orientation.HORIZONTAL, 6);
    header.add (create_avatar_button ());
    header.add (create_name_entry ());
    add (header);

    foreach (var p in individual.personas) {
      add (new EditorPersona (p, aggregator));
    }
    show_all ();
  }

  // Creates the contact's current avatar in a big button on top of the Editor
  private Widget create_avatar_button () {
    this.avatar = new Avatar (PROFILE_SIZE, this.individual);

    var button = new Button ();
    button.get_accessible ().set_name (_("Change avatar"));
    button.image = this.avatar;
    button.clicked.connect (on_avatar_button_clicked);

    return button;
  }

  // Show the avatar popover when the avatar is clicked
  private void on_avatar_button_clicked (Button avatar_button) {
    if (this.avatar_selector == null)
      this.avatar_selector = new AvatarSelector (avatar_button, this.individual);
    this.avatar_selector.show();
  }

  // Creates the big name entry on the top
  private Widget create_name_entry () {
    NameDetails name = this.individual as NameDetails;
    this.name_entry = new Entry ();
    this.name_entry.hexpand = true;
    this.name_entry.valign = Align.CENTER;
    this.name_entry.input_purpose = Gtk.InputPurpose.NAME;
    this.name_entry.placeholder_text = _("Add name");

    // Get primary persona from this.individual
    this.name_entry.text = name.full_name;

    this.name_entry.changed.connect (() => {
      foreach (var p in this.individual.personas) {
        var name_p = p as NameDetails;
        if (name_p != null) {
          name_p.full_name = this.name_entry.get_text ();
        }
      }
    });

    return this.name_entry;
  }
}
