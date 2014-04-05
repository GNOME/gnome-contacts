/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
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

public class Contacts.AddressEditor : Box {
  public Entry? entries[7];
  public PostalAddressFieldDetails details;

  public signal void changed ();

  public AddressEditor (PostalAddressFieldDetails _details) {
    set_hexpand (true);
    set_orientation (Orientation.VERTICAL);

    details = _details;

    for (int i = 0; i < entries.length; i++) {
      string postal_part;
      details.value.get (Contact.postal_element_props[i], out postal_part);

      entries[i] = new Entry ();
      entries[i].set_hexpand (true);
      entries[i].set ("placeholder-text", Contact.postal_element_names[i]);

      if (postal_part != null)
	entries[i].set_text (postal_part);

      entries[i].get_style_context ().add_class ("contacts-entry");
      entries[i].get_style_context ().add_class ("contacts-postal-entry");
      add (entries[i]);

      entries[i].changed.connect (() => {
	  changed ();
	});
    }
  }

  public override void grab_focus () {
    entries[0].grab_focus ();
  }
}

public class Contacts.ContactEditor : Grid {
  Contact contact;

  public struct PropertyData {
    Persona persona;
    Value value;
  }

  struct RowData {
    AbstractFieldDetails<string> details;
  }

  struct Field {
    bool changed;
    HashMap<int, RowData?> rows;
  }

  private int last_row;
  private HashMap<Persona, HashMap<string, Field?> > writable_personas;

  public bool has_birthday_row {
    get; private set; default = false;
  }

  public bool has_nickname_row {
    get; private set; default = false;
  }

  public bool has_notes_row {
    get; private set; default = false;
  }

  Value get_value_from_emails (HashMap<int, RowData?> rows) {
    var new_details = new HashSet<EmailFieldDetails>();

    foreach (var row_entry in rows.entries) {
      var combo = get_child_at (0, row_entry.key) as TypeCombo;
      var entry = get_child_at (1, row_entry.key) as Entry;
      combo.update_details (row_entry.value.details);
      var details = new EmailFieldDetails (entry.get_text (), row_entry.value.details.parameters);
      new_details.add (details);
    }
    var new_value = Value (new_details.get_type ());
    new_value.set_object (new_details);

    return new_value;
  }

  Value get_value_from_phones (HashMap<int, RowData?> rows) {
    var new_details = new HashSet<PhoneFieldDetails>();

    foreach (var row_entry in rows.entries) {
      var combo = get_child_at (0, row_entry.key) as TypeCombo;
      var entry = get_child_at (1, row_entry.key) as Entry;
      combo.update_details (row_entry.value.details);
      var details = new PhoneFieldDetails (entry.get_text (), row_entry.value.details.parameters);
      new_details.add (details);
    }
    var new_value = Value (new_details.get_type ());
    new_value.set_object (new_details);
    return new_value;
  }

  Value get_value_from_urls (HashMap<int, RowData?> rows) {
    var new_details = new HashSet<UrlFieldDetails>();

    foreach (var row_entry in rows.entries) {
      var entry = get_child_at (1, row_entry.key) as Entry;
      var details = new UrlFieldDetails (entry.get_text (), row_entry.value.details.parameters);
      new_details.add (details);
    }
    var new_value = Value (new_details.get_type ());
    new_value.set_object (new_details);
    return new_value;
  }

  Value get_value_from_nickname (HashMap<int, RowData?> rows) {
    var new_value = Value (typeof (string));
    foreach (var row_entry in rows.entries) {
      var entry = get_child_at (1, row_entry.key) as Entry;
      new_value.set_string (entry.get_text ());
    }
    return new_value;
  }

  Value get_value_from_birthday (HashMap<int, RowData?> rows) {
    var new_value = Value (typeof (DateTime));
    foreach (var row_entry in rows.entries) {
      var box = get_child_at (1, row_entry.key) as Grid;
      var day_spin  = box.get_child_at (0, 0) as SpinButton;
      var combo  = box.get_child_at (1, 0) as ComboBoxText;

      var bday = new DateTime.local ((int)box.get_data<int> ("year"),
				     combo.get_active () + 1,
				     (int)day_spin.get_value (),
				     0, 0, 0);
      bday = bday.to_utc ();

      new_value.set_boxed (bday);
    }
    return new_value;
  }

  Value get_value_from_notes (HashMap<int, RowData?> rows) {
    var new_details = new HashSet<NoteFieldDetails>();

    foreach (var row_entry in rows.entries) {
      var text = (get_child_at (1, row_entry.key) as Bin).get_child () as TextView;
      TextIter start, end;
      text.get_buffer ().get_start_iter (out start);
      text.get_buffer ().get_end_iter (out end);
      var value = text.get_buffer ().get_text (start, end, true);
      if (value != "") {
        var details = new NoteFieldDetails (value, row_entry.value.details.parameters);
        new_details.add (details);
      }
    }
    var new_value = Value (new_details.get_type ());
    new_value.set_object (new_details);
    return new_value;
  }

  Value get_value_from_addresses (HashMap<int, RowData?> rows) {
    var new_details = new HashSet<PostalAddressFieldDetails>();

    foreach (var row_entry in rows.entries) {
      var combo = get_child_at (0, row_entry.key) as TypeCombo;
      var addr_editor = get_child_at (1, row_entry.key) as AddressEditor;
      combo.update_details (row_entry.value.details);

      var new_value = new PostalAddress (addr_editor.details.value.po_box,
					 addr_editor.details.value.extension,
					 addr_editor.details.value.street,
					 addr_editor.details.value.locality,
					 addr_editor.details.value.region,
					 addr_editor.details.value.postal_code,
					 addr_editor.details.value.country,
					 addr_editor.details.value.address_format,
					 addr_editor.details.id);
      for (int i = 0; i < addr_editor.entries.length; i++)
	new_value.set (Contact.postal_element_props[i], addr_editor.entries[i].get_text ());

      var details = new PostalAddressFieldDetails(new_value, row_entry.value.details.parameters);
      new_details.add (details);
    }
    var new_value = Value (new_details.get_type ());
    new_value.set_object (new_details);
    return new_value;
  }

  void set_field_changed (int row) {
    foreach (var fields in writable_personas.values) {
      foreach (var entry in fields.entries) {
	if (row in entry.value.rows.keys) {
	  if (entry.value.changed)
	    return;

	  entry.value.changed = true;
	  return;
	}
      }
    }
  }

  new void remove_row (int row) {
    foreach (var fields in writable_personas.values) {
      foreach (var field_entry in fields.entries) {
	foreach (var idx in field_entry.value.rows.keys) {
	  if (idx == row) {
	    var child = get_child_at (0, row);
	    child.destroy ();
	    child = get_child_at (1, row);
	    child.destroy ();
	    child = get_child_at (3, row);
	    child.destroy ();

	    field_entry.value.changed = true;
	    field_entry.value.rows.unset (row);
	    return;
	  }
	}
      }
    }
  }

  void attach_row_with_entry (int row, TypeSet type_set, AbstractFieldDetails details, string value, string? type = null) {
    var combo = new TypeCombo (type_set);
    combo.set_hexpand (false);
    combo.set_active (details);
    if (type != null)
      combo.set_to (type);
    attach (combo, 0, row, 1, 1);

    var value_entry = new Entry ();
    value_entry.set_text (value);
    value_entry.set_hexpand (true);
    attach (value_entry, 1, row, 1, 1);

    var delete_button = new Button ();
    delete_button.get_accessible ().set_name (_("Delete field"));
    var image = new Image.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.add (image);
    attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    combo.changed.connect (() => {
	set_field_changed (row);
      });
    value_entry.changed.connect (() => {
	set_field_changed (row);
      });
    delete_button.clicked.connect (() => {
	remove_row (row);
      });

    value_entry.map.connect (() => {
	if (value == "")
	  value_entry.grab_focus ();
      });
  }

  void attach_row_with_entry_labeled (string title, AbstractFieldDetails? details, string value, int row) {
    var title_label = new Label (title);
    title_label.set_hexpand (false);
    title_label.set_halign (Align.START);
    title_label.margin_end = 6;
    attach (title_label, 0, row, 1, 1);

    var value_entry = new Entry ();
    value_entry.set_text (value);
    value_entry.set_hexpand (true);
    attach (value_entry, 1, row, 1, 1);

    var delete_button = new Button ();
    delete_button.get_accessible ().set_name (_("Delete field"));
    var image = new Image.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.add (image);
    attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    value_entry.changed.connect (() => {
	set_field_changed (row);
      });
    delete_button.clicked.connect (() => {
	remove_row (row);

	/* hacky, ugly way of doing this */
	/* because this func is called with details = null */
	/* only when setting a nickname field */
	if (details == null) {
	  has_nickname_row = false;
	}
      });

    value_entry.map.connect (() => {
	if (value == "")
	  value_entry.grab_focus ();
      });
  }

  void attach_row_with_text_labeled (string title, AbstractFieldDetails? details, string value, int row) {
    var title_label = new Label (title);
    title_label.set_hexpand (false);
    title_label.set_halign (Align.START);
    title_label.set_valign (Align.START);
    title_label.margin_top = 3;
    title_label.margin_end = 6;
    attach (title_label, 0, row, 1, 1);

    var sw = new ScrolledWindow (null, null);
    sw.set_shadow_type (ShadowType.OUT);
    sw.set_size_request (-1, 100);
    var value_text = new TextView ();
    value_text.get_buffer ().set_text (value);
    value_text.set_hexpand (true);
    value_text.get_style_context ().add_class ("contacts-entry");
    sw.add (value_text);
    attach (sw, 1, row, 1, 1);

    var delete_button = new Button ();
    delete_button.get_accessible ().set_name (_("Delete field"));
    var image = new Image.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.add (image);
    delete_button.set_valign (Align.START);
    attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    value_text.get_buffer ().changed.connect (() => {
	set_field_changed (row);
      });
    delete_button.clicked.connect (() => {
	remove_row (row);
	/* eventually will need to check against the details type */
	has_notes_row = false;
      });

    value_text.map.connect (() => {
	if (value == "")
	  value_text.grab_focus ();
      });
  }

  void attach_row_for_birthday (string title, AbstractFieldDetails? details, DateTime birthday, int row) {
    var title_label = new Label (title);
    title_label.set_hexpand (false);
    title_label.set_halign (Align.START);
    title_label.margin_end = 6;
    attach (title_label, 0, row, 1, 1);

    var box = new Grid ();
    box.set_column_spacing (12);
    var day_spin = new SpinButton.with_range (1.0, 31.0, 1.0);
    day_spin.set_digits (0);
    day_spin.numeric = true;
    day_spin.set_value ((double)birthday.to_local ().get_day_of_month ());

    var combo = new ComboBoxText ();
    combo.append_text (_("January"));
    combo.append_text (_("February"));
    combo.append_text (_("March"));
    combo.append_text (_("April"));
    combo.append_text (_("May"));
    combo.append_text (_("June"));
    combo.append_text (_("July"));
    combo.append_text (_("August"));
    combo.append_text (_("September"));
    combo.append_text (_("October"));
    combo.append_text (_("November"));
    combo.append_text (_("December"));
    combo.set_active (birthday.to_local ().get_month () - 1);
    combo.get_style_context ().add_class ("contacts-combo");
    combo.set_hexpand (true);

    /* hack to preserver year in order to compare latter full date */
    box.set_data ("year", birthday.to_local ().get_year ());
    box.add (day_spin);
    box.add (combo);

    attach (box, 1, row, 1, 1);

    var delete_button = new Button ();
    delete_button.get_accessible ().set_name (_("Delete field"));
    var image = new Image.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.add (image);
    attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    day_spin.changed.connect (() => {
	set_field_changed (row);
      });
    combo.changed.connect (() => {
	set_field_changed (row);
      });
    delete_button.clicked.connect (() => {
	remove_row (row);
	has_birthday_row = false;
      });
  }

  void attach_row_for_address (int row, TypeSet type_set, PostalAddressFieldDetails details, string? type = null) {
    var combo = new TypeCombo (type_set);
    combo.set_hexpand (false);
    combo.set_active (details);
    if (type != null)
      combo.set_to (type);
    attach (combo, 0, row, 1, 1);

    var value_address = new AddressEditor (details);
    attach (value_address, 1, row, 1, 1);

    var delete_button = new Button ();
    delete_button.get_accessible ().set_name (_("Delete field"));
    var image = new Image.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.add (image);
    delete_button.set_valign (Align.START);
    attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    combo.changed.connect (() => {
	set_field_changed (row);
      });
    value_address.changed.connect (() => {
	set_field_changed (row);
      });
    delete_button.clicked.connect (() => {
	remove_row (row);
      });

    value_address.map.connect (() => {
	value_address.grab_focus ();
      });
  }

  void add_edit_row (Persona p, string prop_name, ref int row, bool add_empty = false, string? type = null) {
    /* Here, we will need to add manually every type of field,
     * we're planning to allow editing on */
    switch (prop_name) {
    case "email-addresses":
      var rows = new HashMap<int, RowData?> ();
      if (add_empty) {
	var detail_field = new EmailFieldDetails ("");
	attach_row_with_entry (row, TypeSet.email, detail_field, "", type);
	rows.set (row, { detail_field });
	row++;
      } else {
	var details = p as EmailDetails;
	if (details != null) {
	  var emails = Contact.sort_fields<EmailFieldDetails>(details.email_addresses);
	  foreach (var email in emails) {
	    attach_row_with_entry (row, TypeSet.email, email, email.value);
	    rows.set (row, { email });
	    row++;
	  }
	}
      }
      if (! rows.is_empty) {
	if (writable_personas[p].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[p][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[p].set (prop_name, { false, rows });
	}
      }
      break;
    case "phone-numbers":
      var rows = new HashMap<int, RowData?> ();
      if (add_empty) {
	var detail_field = new PhoneFieldDetails ("");
	attach_row_with_entry (row, TypeSet.phone, detail_field, "", type);
	rows.set (row, { detail_field });
	row++;
      } else {
	var details = p as PhoneDetails;
	if (details != null) {
	  var phones = Contact.sort_fields<PhoneFieldDetails>(details.phone_numbers);
	  foreach (var phone in phones) {
	    attach_row_with_entry (row, TypeSet.phone, phone, phone.value, type);
	    rows.set (row, { phone });
	    row++;
	  }
	}
      }
      if (! rows.is_empty) {
	if (writable_personas[p].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[p][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[p].set (prop_name, { false, rows });
	}
      }
      break;
    case "urls":
      var rows = new HashMap<int, RowData?> ();
      if (add_empty) {
	var detail_field = new UrlFieldDetails ("");
	attach_row_with_entry_labeled (_("Website"), detail_field, "", row);
	rows.set (row, { detail_field });
	row++;
      } else {
	var url_details = p as UrlDetails;
	if (url_details != null) {
	  foreach (var url in url_details.urls) {
	    attach_row_with_entry_labeled (_("Website"), url, url.value, row);
	    rows.set (row, { url });
	    row++;
	  }
	}
      }
      if (! rows.is_empty) {
	if (writable_personas[p].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[p][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[p].set (prop_name, { false, rows });
	}
      }
      break;
    case "nickname":
      var rows = new HashMap<int, RowData?> ();
      if (add_empty) {
	attach_row_with_entry_labeled (_("Nickname"), null, "", row);
	rows.set (row, { null });
	row++;
      } else {
	var name_details = p as NameDetails;
	if (name_details != null) {
	  if (is_set (name_details.nickname)) {
	    attach_row_with_entry_labeled (_("Nickname"), null, name_details.nickname, row);
	    rows.set (row, { null });
	    row++;
	  }
	}
      }
      if (! rows.is_empty) {
	has_nickname_row = true;
	if (writable_personas[p].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[p][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[p].set (prop_name, { false, rows });
	}
      }
      break;
    case "birthday":
      var rows = new HashMap<int, RowData?> ();
      if (add_empty) {
	var today = new DateTime.now_local ();
	attach_row_for_birthday (_("Birthday"), null, today, row);
	rows.set (row, { null });
	row++;
      } else {
	var birthday_details = p as BirthdayDetails;
	if (birthday_details != null) {
	  if (birthday_details.birthday != null) {
	    attach_row_for_birthday (_("Birthday"), null, birthday_details.birthday, row);
	    rows.set (row, { null });
	    row++;
	  }
	}
      }
      if (! rows.is_empty) {
	has_birthday_row = true;
	writable_personas[p].set (prop_name, { add_empty, rows });
      }
      break;
    case "notes":
      var rows = new HashMap<int, RowData?> ();
      if (add_empty) {
	var detail_field = new NoteFieldDetails ("");
	attach_row_with_text_labeled (_("Note"), detail_field, "", row);
	rows.set (row, { detail_field });
	row++;
      } else {
	var note_details = p as NoteDetails;
	if (note_details != null || add_empty) {
	  foreach (var note in note_details.notes) {
	    attach_row_with_text_labeled (_("Note"), note, note.value, row);
	    rows.set (row, { note });
	    row++;
	  }
	}
      }
      if (! rows.is_empty) {
	has_notes_row = true;
	if (writable_personas[p].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[p][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[p].set (prop_name, { false, rows });
	}
      }
      break;
    case "postal-addresses":
      var rows = new HashMap<int, RowData?> ();
      if (add_empty) {
	var detail_field = new PostalAddressFieldDetails (
                             new PostalAddress (null,
						null,
						null,
						null,
						null,
						null,
						null,
						null,
						null));
	attach_row_for_address (row, TypeSet.general, detail_field, type);
	rows.set (row, { detail_field });
	row++;
      } else {
	var address_details = p as PostalAddressDetails;
	if (address_details != null) {
	  foreach (var addr in address_details.postal_addresses) {
	    attach_row_for_address (row, TypeSet.general, addr, type);
	    rows.set (row, { addr });
	    row++;
	  }
	}
      }
      if (! rows.is_empty) {
	if (writable_personas[p].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[p][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[p].set (prop_name, { false, rows });
	}
      }
      break;
    }
  }

  void insert_row_at (int idx) {
    foreach (var field_maps in writable_personas.values) {
      foreach (var field in field_maps.values) {
	foreach (var row in field.rows.keys) {
	  if (row >= idx) {
	    var new_rows = new HashMap <int, RowData?> ();
	    foreach (var old_row in field.rows.keys) {
	      /* move all rows +1 */
	      new_rows.set (old_row + 1, field.rows[old_row]);
	    }
	    field.rows = new_rows;
	    break;
	  }
	}
      }
    }
    insert_row (idx);
  }

  public ContactEditor () {
    set_row_spacing (12);
    set_column_spacing (12);

    writable_personas = new HashMap<Persona, HashMap<string, Field?> > ();
  }

  public void update (Contact c) {
    contact = c;

    var image_frame = new ContactFrame (PROFILE_SIZE, true);
    image_frame.set_vexpand (false);
    image_frame.set_valign (Align.START);
    (image_frame.get_child () as Button).set_relief (ReliefStyle.NORMAL);
    image_frame.clicked.connect ( () => {
	change_avatar (c, image_frame);
      });
    c.keep_widget_uptodate (image_frame,  (w) => {
	(w as ContactFrame).set_image (c.individual, c);
      });
    attach (image_frame,  0, 0, 1, 3);

    var name_entry = new Entry ();
    name_entry.set_hexpand (true);
    name_entry.set_valign (Align.CENTER);
    name_entry.set_text (c.display_name);
    name_entry.set_data ("changed", false);
    attach (name_entry,  1, 0, 3, 3);

    /* structured name change */
    name_entry.changed.connect (() => {
	name_entry.set_data ("changed", true);
      });

    int i = 3;
    int last_store_position = 0;
    bool is_first_persona = true;

    var personas = c.get_personas_for_display ();
    foreach (var p in personas) {
      if (!is_first_persona) {
	var store_name = new Label("");
	store_name.set_markup (Markup.printf_escaped ("<span font='16px bold'>%s</span>",
						      Contact.format_persona_store_name_for_contact (p)));
	store_name.set_halign (Align.START);
	store_name.xalign = 0.0f;
	store_name.margin_start = 6;
	attach (store_name, 0, i, 2, 1);
	last_store_position = ++i;
      }

      var rw_props = Contact.sort_persona_properties (p.writeable_properties);
      if (rw_props.length != 0) {
	writable_personas.set (p, new HashMap<string, Field?> ());
	foreach (var prop in rw_props) {
	  add_edit_row (p, prop, ref i);
	}
      }

      if (is_first_persona) {
	last_row = i - 1;
      }

      if (i != 3) {
	is_first_persona = false;
      }

      if (i == last_store_position) {
	i--;
	get_child_at (0, i).destroy ();
      }
    }
  }

  public void clear () {
    foreach (var w in get_children ()) {
      w.destroy ();
    }

    /* clean metadata as well */
    has_birthday_row = false;
    has_nickname_row = false;
    has_notes_row = false;
  }

  public HashMap<string, PropertyData?> properties_changed () {
    var props_set = new HashMap<string, PropertyData?> ();

    foreach (var entry in writable_personas.entries) {
      foreach (var field_entry in entry.value.entries) {
	if (field_entry.value.changed && !props_set.has_key (field_entry.key)) {
	  PropertyData p = PropertyData ();
	  p.persona = entry.key;

	  switch (field_entry.key) {
	    case "email-addresses":
	      p.value = get_value_from_emails (field_entry.value.rows);
	      break;
	    case "phone-numbers":
	      p.value = get_value_from_phones (field_entry.value.rows);
	      break;
	    case "urls":
	      p.value = get_value_from_urls (field_entry.value.rows);
	      break;
	    case "nickname":
	      p.value = get_value_from_nickname (field_entry.value.rows);
	      break;
	    case "birthday":
	      p.value = get_value_from_birthday (field_entry.value.rows);
	      break;
	    case "notes":
	      p.value = get_value_from_notes (field_entry.value.rows);
	      break;
            case "postal-addresses":
	      p.value = get_value_from_addresses (field_entry.value.rows);
	      break;
	  }

	  props_set.set (field_entry.key, p);
	}
      }
    }

    return props_set;
  }

  public bool name_changed () {
    var name_entry = get_child_at (1, 0) as Entry;
    return name_entry.get_data<bool> ("changed");
  }

  public Value get_full_name_value () {
    Value v = Value (typeof (string));
    var name_entry = get_child_at (1, 0) as Entry;
    v.set_string (name_entry.get_text ());
    return v;
  }

  public void add_new_row_for_property (Persona? p, string prop_name, string? type = null) {
    /* Somehow, I need to ensure that p is the main/default/first persona */
    Persona persona;
    if (p == null) {
      persona = new FakePersona (contact);
      writable_personas.set (persona, new HashMap<string, Field?> ());
    } else {
      persona = p;
    }

    int next_idx = 0;
    foreach (var fields in writable_personas.values) {
      if (fields.has_key (prop_name)) {
	  foreach (var idx in fields[prop_name].rows.keys) {
	    if (idx < last_row)
	      next_idx = idx > next_idx ? idx : next_idx;
	  }
	  break;
      }
    }
    next_idx = (next_idx == 0 ? last_row : next_idx) + 1;
    insert_row_at (next_idx);
    add_edit_row (persona, prop_name, ref next_idx, true, type);
    last_row++;
    show_all ();
  }
}
