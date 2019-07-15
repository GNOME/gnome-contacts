/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
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

/**
 * A parent class for the {@link ContactEditor} and the {@link ContactSheet}.
 *
 * This exploits the common structure of both widgets: they both display a
 * (possibly empty) contact, starting with a header and subsequently iterating
 * over the several {@link Folks.Persona}s, displaying their properties.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-contact-form.ui")]
public abstract class Contacts.ContactForm : Grid {

  protected const string[] SORTED_PROPERTIES = {
    "email-addresses",
    "phone-numbers",
    "im-addresses",
    "urls",
    "nickname",
    "birthday",
    "postal-addresses",
    "notes"
  };

  protected Individual? individual;

  protected Store store;

  [GtkChild]
  private ScrolledWindow main_sw;

  [GtkChild]
  protected Grid container_grid;
  protected int last_row = 0;

  construct {
    this.container_grid.set_focus_vadjustment (this.main_sw.get_vadjustment ());
    this.main_sw.get_style_context ().add_class ("contacts-contact-form");
  }

  protected string[] sort_persona_properties (string[] props) {
    CompareDataFunc<string> compare_properties = (a, b) => {
        foreach (var prop in SORTED_PROPERTIES) {
          if (a == prop)
            return (b == prop)? 0 : -1;

          if (b == prop)
            return 1;
        }

        return 0;
      };

    var sorted_props = new ArrayList<string> ();
    foreach (var s in props)
      sorted_props.add (s);

    sorted_props.sort ((owned) compare_properties);
    return sorted_props.to_array ();
  }

  protected Label create_persona_store_label (Persona p) {
    var store_name = new Label("");
    store_name.set_markup (Markup.printf_escaped ("<span font='16px bold'>%s</span>",
                           Contacts.Utils.format_persona_store_name_for_contact (p)));
    store_name.set_halign (Align.START);
    store_name.xalign = 0.0f;
    store_name.margin_start = 6;

    return store_name;
  }
}
