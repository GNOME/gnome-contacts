/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 * Copyright (C) 2019 Purism SPC
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
 * A widget that allows the user to edit a given {@link Contact}.
 */
public class Contacts.ContactEditor : Gtk.Box {

  private Individual individual;
  private unowned Gtk.Entry name_entry;
  private unowned Avatar avatar;

  construct {
    this.orientation = Gtk.Orientation.VERTICAL;
    this.spacing = 12;

    this.add_css_class ("contacts-contact-editor");
  }

  public ContactEditor (Individual individual, IndividualAggregator aggregator) {
    this.individual = individual;

    Gtk.Box header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
    header.append (create_avatar_button ());
    header.append (create_name_entry ());
    append (header);

    foreach (var p in individual.personas) {
      append (new EditorPersona (p, aggregator));
    }
  }

  // Creates the contact's current avatar in a big button on top of the Editor
  private Gtk.Widget create_avatar_button () {
    var avatar = new Avatar (PROFILE_SIZE, this.individual);
    this.avatar = avatar;

    var button = new Gtk.Button ();
    button.tooltip_text = _("Change avatar");
    button.set_child (this.avatar);
    button.clicked.connect (on_avatar_button_clicked);

    return button;
  }

  // Show the avatar popover when the avatar is clicked
  private void on_avatar_button_clicked (Gtk.Button avatar_button) {
    var avatar_selector = new AvatarSelector (this.individual, get_root () as Gtk.Window);
    avatar_selector.response.connect ((response) => {
      if (response == Gtk.ResponseType.ACCEPT) {
        avatar_selector.save_selection.begin ((obj, res) => {
          try {
            avatar_selector.save_selection.end (res);
            this.avatar.set_pixbuf (avatar_selector.selected_avatar);
          } catch (Error e) {
            warning ("Failed to set avatar: %s", e.message);
            Utils.show_error_dialog (_("Failed to set avatar."),
                                     get_root () as Gtk.Window);
          }
        });
      }
      avatar_selector.destroy ();
    });
    avatar_selector.show ();
  }

  // Creates the big name entry on the top
  private Gtk.Widget create_name_entry () {
    NameDetails name = this.individual as NameDetails;
    var entry = new Gtk.Entry ();
    this.name_entry = entry;
    this.name_entry.hexpand = true;
    this.name_entry.valign = Gtk.Align.CENTER;
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
