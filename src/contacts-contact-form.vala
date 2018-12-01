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

  protected Contact? contact;

  protected Store store;

  [GtkChild]
  private ScrolledWindow main_sw;

  [GtkChild]
  protected Grid container_grid;

  [GtkChild]
  protected ListBox form_container;
  protected GLib.ListStore fields = new GLib.ListStore (typeof (PropertyField));

  protected SizeGroup labels_sizegroup = new SizeGroup (SizeGroupMode.HORIZONTAL);
  protected SizeGroup values_sizegroup = new SizeGroup (SizeGroupMode.HORIZONTAL);
  protected SizeGroup actions_sizegroup = new SizeGroup (SizeGroupMode.HORIZONTAL);

  // Seperate treatment for the header widgets
  protected Widget avatar_widget;
  protected Widget name_widget;

  construct {
    this.container_grid.set_focus_vadjustment (this.main_sw.get_vadjustment ());
    this.main_sw.get_style_context ().add_class ("contacts-contact-form");

    this.form_container.bind_model (fields, create_row);
    this.form_container.set_header_func (create_persona_store_header);
  }

  private Gtk.Widget create_row (Object object) {
    return ((PropertyField) object).create_row (labels_sizegroup, values_sizegroup, actions_sizegroup);
  }

  public void create_persona_store_header (ListBoxRow row, ListBoxRow? before) {
    // Leave out the persona store header at the start
    if (before == null) {
      row.set_header (null);
      return;
    }

    PropertyWidget current = (PropertyWidget) row;
    PropertyWidget previous = (PropertyWidget) before;
    if (current.field.persona == null || previous.field.persona == null)
      return;
    if (current.field.persona == previous.field.persona)
      return;

    var label = create_persona_store_label (current.field.persona);
    row.set_header (label);
  }

  private static int compare_fields (Object obj_a, Object obj_b) {
    unowned PropertyField a = (PropertyField) obj_a;
    unowned PropertyField b = (PropertyField) obj_b;

    // First compare personas
    var persona_comparison = Utils.compare_personas_on_store (a.persona, b.persona);
    if (persona_comparison != 0)
      return persona_comparison;

    // Then compare properties (by name)
    return compare_property_names (a.property_name, b.property_name);
  }

  private static int compare_property_names (string a, string b) {
    foreach (var prop in SORTED_PROPERTIES) {
      if (a == prop)
        return (b == prop)? 0 : -1;

      if (b == prop)
        return 1;
    }

    return 0;
  }

  protected Label create_persona_store_label (Persona p) {
    var store_name = new Label("");
    store_name.set_markup (Markup.printf_escaped ("<span font='16px bold'>%s</span>",
                           Contact.format_persona_store_name_for_contact (p)));
    store_name.set_halign (Align.START);
    store_name.xalign = 0.0f;
    store_name.margin_start = 6;
    store_name.visible = true;

    return store_name;
  }

  protected PropertyField? get_property_field_for_name (string name) {
    for (uint i = 0; i < this.fields.get_n_items(); i++) {
      var field = (PropertyField) this.fields.get_item (i);
      if (field.property_name == name)
        return field;
    }

    return null;
  }

  protected void add_field (PropertyField field) {
    this.fields.insert_sorted (field, compare_fields);
  }

  protected void attach_avatar_widget (Widget avatar_widget) {
    avatar_widget.vexpand = false;
    avatar_widget.halign = Align.START;
    container_grid.attach (avatar_widget, 0, 0);
    this.labels_sizegroup.add_widget (avatar_widget);
  }

  protected void set_name_widget (Widget name_widget) {
    this.name_widget = name_widget;
    this.name_widget.hexpand = true;
    this.name_widget.valign = Align.CENTER;
    this.container_grid.attach (this.name_widget, 1, 0);
  }
}
