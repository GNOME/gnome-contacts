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
  public Entry? entries[7];  /* must be the number of elements in postal_element_props */
  public PostalAddressFieldDetails details;

  public const string[] postal_element_props = {"street", "extension", "locality", "region", "postal_code", "po_box", "country"};
  public static string[] postal_element_names = {_("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

  public signal void changed ();

  public AddressEditor (PostalAddressFieldDetails _details) {
    set_hexpand (true);
    set_orientation (Orientation.VERTICAL);

    details = _details;

    for (int i = 0; i < entries.length; i++) {
      string postal_part;
      details.value.get (AddressEditor.postal_element_props[i], out postal_part);

      entries[i] = new Entry ();
      entries[i].set_hexpand (true);
      entries[i].set ("placeholder-text", AddressEditor.postal_element_names[i]);

      if (postal_part != null)
	entries[i].set_text (postal_part);

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

/**
 * A widget that allows the user to edit a given {@link Contact}.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-contact-editor.ui")]
public class Contacts.ContactEditor : ContactForm {

  private const string[] DEFAULT_PROPS_NEW_CONTACT = {
    "email-addresses.personal",
    "phone-numbers.cell",
    "postal-addresses.home"
  };

  [GtkChild]
  private Grid container_grid;
  private weak Widget focus_widget;

  private Entry name_entry;

  private Avatar avatar;

  [GtkChild]
  private ScrolledWindow main_sw;

  [GtkChild]
  private MenuButton add_detail_button;

  [GtkChild]
  public Button linked_button;

  [GtkChild]
  public Button remove_button;

  public struct PropertyData {
    Persona? persona;
    Value value;
  }

  struct RowData {
    AbstractFieldDetails details;
  }

  struct Field {
    bool changed;
    HashMap<int, RowData?> rows;
  }

  /* the key of the hash_map is the uid of the persona */
  private HashMap<string, HashMap<string, Field?>> writable_personas;

  public bool has_birthday_row {
    get; private set; default = false;
  }

  public bool has_nickname_row {
    get; private set; default = false;
  }

  public bool has_notes_row {
    get; private set; default = false;
  }

  construct {
    this.writable_personas = new HashMap<string, HashMap<string, Field?>> ();

    this.container_grid.set_focus_vadjustment (this.main_sw.get_vadjustment ());

    this.main_sw.get_style_context ().add_class ("contacts-main-view");
    this.main_sw.get_style_context ().add_class ("view");
  }

  public ContactEditor (Contact? contact, Store store, GLib.ActionGroup editor_actions) {
    this.store = store;
    this.contact = contact;

    this.add_detail_button.get_popover ().insert_action_group ("edit", editor_actions);

    if (contact != null) {
      this.remove_button.sensitive = contact.can_remove_personas ();
      this.linked_button.sensitive = contact.individual.personas.size > 1;
    } else {
      this.remove_button.hide ();
      this.linked_button.hide ();
    }

    create_avatar_button ();
    create_name_entry ();

    if (contact != null)
      fill_in_contact ();
    else
      fill_in_empty ();

    show_all ();
  }

  private void fill_in_contact () {
    int i = 3;
    int last_store_position = 0;
    bool is_first_persona = true;

    var personas = this.contact.get_personas_for_display ();
    foreach (var p in personas) {
      if (!is_first_persona) {
        this.container_grid.attach (create_persona_store_label (p), 0, i, 2);
        last_store_position = ++i;
      }

      var rw_props = sort_persona_properties (p.writeable_properties);
      if (rw_props.length != 0) {
        this.writable_personas[p.uid] = new HashMap<string, Field?> ();
        foreach (var prop in rw_props)
          add_edit_row (p, prop, ref i);
      }

      if (is_first_persona)
        this.last_row = i - 1;

      if (i != 3)
        is_first_persona = false;

      if (i == last_store_position) {
        i--;
        this.container_grid.get_child_at (0, i).destroy ();
      }
    }
  }

  private void fill_in_empty () {
    this.last_row = 2;

    this.writable_personas["null-persona.hack"] = new HashMap<string, Field?> ();
    foreach (var prop in DEFAULT_PROPS_NEW_CONTACT) {
      var tok = prop.split (".");
      add_new_row_for_property (null, tok[0], tok[1].up ());
    }

    this.focus_widget = this.name_entry;
  }

  Value get_value_from_emails (HashMap<int, RowData?> rows) {
    var new_details = new HashSet<EmailFieldDetails>();

    foreach (var row_entry in rows.entries) {
      var combo = container_grid.get_child_at (0, row_entry.key) as TypeCombo;
      var entry = container_grid.get_child_at (1, row_entry.key) as Entry;

      /* Ignore empty entries. */
      if (entry.get_text () == "")
        continue;

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
      var combo = container_grid.get_child_at (0, row_entry.key) as TypeCombo;
      var entry = container_grid.get_child_at (1, row_entry.key) as Entry;

      /* Ignore empty entries. */
      if (entry.get_text () == "")
        continue;

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
      var entry = container_grid.get_child_at (1, row_entry.key) as Entry;

      /* Ignore empty entries. */
      if (entry.get_text () == "")
        continue;

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
      var entry = container_grid.get_child_at (1, row_entry.key) as Entry;

      /* Ignore empty entries. */
      if (entry.get_text () == "")
        continue;

      new_value.set_string (entry.get_text ());
    }
    return new_value;
  }

  Value get_value_from_birthday (HashMap<int, RowData?> rows) {
    var new_value = Value (typeof (DateTime));
    foreach (var row_entry in rows.entries) {
      var box = container_grid.get_child_at (1, row_entry.key) as Grid;
      var day_spin  = box.get_child_at (0, 0) as SpinButton;
      var combo  = box.get_child_at (1, 0) as ComboBoxText;
      var year_spin  = box.get_child_at (2, 0) as SpinButton;

      var bday = new DateTime.local (year_spin.get_value_as_int (),
				     combo.get_active () + 1,
				     day_spin.get_value_as_int (),
				     0, 0, 0);
      bday = bday.to_utc ();

      new_value.set_boxed (bday);
    }
    return new_value;
  }

  Value get_value_from_notes (HashMap<int, RowData?> rows) {
    var new_details = new HashSet<NoteFieldDetails>();

    foreach (var row_entry in rows.entries) {
      var text = (container_grid.get_child_at (1, row_entry.key) as Bin).get_child () as TextView;
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
      var combo = container_grid.get_child_at (0, row_entry.key) as TypeCombo;
      var addr_editor = container_grid.get_child_at (1, row_entry.key) as AddressEditor;
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
	new_value.set (AddressEditor.postal_element_props[i], addr_editor.entries[i].get_text ());

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
	    var child = container_grid.get_child_at (0, row);
	    child.destroy ();
	    child = container_grid.get_child_at (1, row);
	    child.destroy ();
	    child = container_grid.get_child_at (3, row);
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
    combo.set_valign (Align.CENTER);
    container_grid.attach (combo, 0, row, 1, 1);

    var value_entry = new Entry ();
    value_entry.set_text (value);
    value_entry.set_hexpand (true);
    container_grid.attach (value_entry, 1, row, 1, 1);

    if (type_set == TypeSet.email) {
      value_entry.placeholder_text = _("Add email");
    } else if (type_set == TypeSet.phone) {
      value_entry.placeholder_text = _("Add number");
    }

    var delete_button = new Button.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.get_accessible ().set_name (_("Delete field"));
    container_grid.attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    combo.changed.connect (() => {
	set_field_changed (get_current_row (combo));
      });
    value_entry.changed.connect (() => {
	set_field_changed (get_current_row (value_entry));
      });
    delete_button.clicked.connect (() => {
	remove_row (get_current_row (delete_button));
      });

    if (value == "")
      focus_widget = value_entry;
  }

  void attach_row_with_entry_labeled (string title, AbstractFieldDetails? details, string value, int row) {
    var title_label = new Label (title);
    title_label.set_hexpand (false);
    title_label.set_halign (Align.START);
    title_label.margin_end = 6;
    container_grid.attach (title_label, 0, row, 1, 1);

    var value_entry = new Entry ();
    value_entry.set_text (value);
    value_entry.set_hexpand (true);
    container_grid.attach (value_entry, 1, row, 1, 1);

    var delete_button = new Button.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.get_accessible ().set_name (_("Delete field"));
    container_grid.attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    value_entry.changed.connect (() => {
	set_field_changed (get_current_row (value_entry));
      });
    delete_button.clicked.connect_after (() => {
	remove_row (get_current_row (delete_button));
      });

    if (value == "")
      focus_widget = value_entry;
  }

  void attach_row_with_text_labeled (string title, AbstractFieldDetails? details, string value, int row) {
    var title_label = new Label (title);
    title_label.set_hexpand (false);
    title_label.set_halign (Align.START);
    title_label.set_valign (Align.START);
    title_label.margin_top = 3;
    title_label.margin_end = 6;
    container_grid.attach (title_label, 0, row, 1, 1);

    var sw = new ScrolledWindow (null, null);
    sw.set_shadow_type (ShadowType.OUT);
    sw.set_size_request (-1, 100);
    var value_text = new TextView ();
    value_text.get_buffer ().set_text (value);
    value_text.set_hexpand (true);
    sw.add (value_text);
    container_grid.attach (sw, 1, row, 1, 1);

    var delete_button = new Button.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.get_accessible ().set_name (_("Delete field"));
    delete_button.set_valign (Align.START);
    container_grid.attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    value_text.get_buffer ().changed.connect (() => {
	set_field_changed (get_current_row (sw));
      });
    delete_button.clicked.connect (() => {
	remove_row (get_current_row (delete_button));
	/* eventually will need to check against the details type */
	has_notes_row = false;
      });

    if (value == "")
      focus_widget = value_text;
  }

  delegate void AdjustingDateFn();

  void attach_row_for_birthday (string title, AbstractFieldDetails? details, DateTime birthday, int row) {
    var title_label = new Label (title);
    title_label.set_hexpand (false);
    title_label.set_halign (Align.START);
    title_label.margin_end = 6;
    container_grid.attach (title_label, 0, row, 1, 1);

    var box = new Grid ();
    box.set_column_spacing (12);
    var day_spin = new SpinButton.with_range (1.0, 31.0, 1.0);
    day_spin.set_digits (0);
    day_spin.numeric = true;
    day_spin.set_value ((double)birthday.to_local ().get_day_of_month ());

    var month_combo = new ComboBoxText ();
    var january = new DateTime.local (1, 1, 1, 1, 1, 1);
    for (int i = 0; i < 12; i++) {
        var month = january.add_months (i);
        month_combo.append_text (month.format ("%B"));
    }
    month_combo.set_active (birthday.to_local ().get_month () - 1);
    month_combo.hexpand = true;

    var year_spin = new SpinButton.with_range (1800, 3000, 1);
    year_spin.set_digits (0);
    year_spin.numeric = true;
    year_spin.set_value ((double)birthday.to_local ().get_year ());

    box.add (day_spin);
    box.add (month_combo);
    box.add (year_spin);

    container_grid.attach (box, 1, row, 1, 1);

    var delete_button = new Button.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.get_accessible ().set_name (_("Delete field"));
    container_grid.attach (delete_button, 3, row, 1, 1);

    AdjustingDateFn fn = () => {
      int[] month_of_31 = {3, 5, 8, 10};
      if (month_combo.get_active () in month_of_31) {
        day_spin.set_range (1, 30);
      } else if (month_combo.get_active () == 1) {
        if (year_spin.get_value_as_int () % 4 == 0 &&
            year_spin.get_value_as_int () % 100 != 0) {
          day_spin.set_range (1, 29);
        } else {
          day_spin.set_range (1, 28);
        }
      }
    };

    /* Notify change to upper layer */
    day_spin.changed.connect (() => {
        set_field_changed (get_current_row (day_spin));
      });
    month_combo.changed.connect (() => {
        set_field_changed (get_current_row (month_combo));

        /* adjusting day_spin value using selected month constraints*/
        fn ();
      });
    year_spin.changed.connect (() => {
        set_field_changed (get_current_row (year_spin));

        fn ();
      });
    delete_button.clicked.connect (() => {
        remove_row (get_current_row (delete_button));
        has_birthday_row = false;
      });
  }

  void attach_row_for_address (int row, TypeSet type_set, PostalAddressFieldDetails details, string? type = null) {
    var combo = new TypeCombo (type_set);
    combo.set_hexpand (false);
    combo.set_active (details);
    if (type != null)
      combo.set_to (type);
    container_grid.attach (combo, 0, row, 1, 1);

    var value_address = new AddressEditor (details);
    container_grid.attach (value_address, 1, row, 1, 1);

    var delete_button = new Button.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.get_accessible ().set_name (_("Delete field"));
    delete_button.set_valign (Align.START);
    container_grid.attach (delete_button, 3, row, 1, 1);

    /* Notify change to upper layer */
    combo.changed.connect (() => {
	set_field_changed (get_current_row (combo));
      });
    value_address.changed.connect (() => {
	set_field_changed (get_current_row (value_address));
      });
    delete_button.clicked.connect (() => {
	remove_row (get_current_row (delete_button));
      });

    focus_widget = value_address;
  }

  void add_edit_row (Persona? p, string prop_name, ref int row, bool add_empty = false, string? type = null) {
    /* Here, we will need to add manually every type of field,
     * we're planning to allow editing on */
    string persona_uid = p != null ? p.uid : "null-persona.hack";
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
	if (writable_personas[persona_uid].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[persona_uid][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[persona_uid].set (prop_name, { false, rows });
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
	if (writable_personas[persona_uid].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[persona_uid][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[persona_uid].set (prop_name, { false, rows });
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
	if (writable_personas[persona_uid].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[persona_uid][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[persona_uid].set (prop_name, { false, rows });
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
	var delete_button = container_grid.get_child_at (3, row - 1) as Button;
	delete_button.clicked.connect (() => {
	    has_nickname_row = false;
	  });

	if (writable_personas[persona_uid].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[persona_uid][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[persona_uid].set (prop_name, { false, rows });
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
	writable_personas[persona_uid].set (prop_name, { add_empty, rows });
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
	if (writable_personas[persona_uid].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[persona_uid][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[persona_uid].set (prop_name, { false, rows });
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
	if (writable_personas[persona_uid].has_key (prop_name)) {
	  foreach (var entry in rows.entries) {
	    writable_personas[persona_uid][prop_name].rows.set (entry.key, entry.value);
	  }
	} else {
	  writable_personas[persona_uid].set (prop_name, { false, rows });
	}
      }
      break;
    }
  }

  int get_current_row (Widget child) {
    int row;

    container_grid.child_get (child, "top-attach", out row);
    return row;
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
    foreach (var entry in writable_personas.entries) {
      foreach (var field_entry in entry.value.entries) {
	foreach (var row in field_entry.value.rows.keys) {
	  if (row >= idx) {
	    var new_rows = new HashMap <int, RowData?> ();
	    foreach (var old_row in field_entry.value.rows.keys) {
	      new_rows.set (old_row + 1, field_entry.value.rows[old_row]);
	    }
	    field_entry.value.rows = new_rows;
	    break;
	  }
	}
      }
    }
    container_grid.insert_row (idx);
  }

  [GtkCallback]
  private void on_container_grid_size_allocate (Allocation alloc) {
    if (focus_widget != null &&
        focus_widget is Widget) {
      focus_widget.grab_focus ();
      focus_widget = null;
    }
  }

  public HashMap<string, PropertyData?> properties_changed () {
    var props_set = new HashMap<string, PropertyData?> ();

    foreach (var entry in writable_personas.entries) {
      foreach (var field_entry in entry.value.entries) {
	if (field_entry.value.changed && !props_set.has_key (field_entry.key)) {
	  PropertyData p = PropertyData ();
	  p.persona = null;
	  if (contact != null) {
	    p.persona = contact.find_persona_from_uid (entry.key);
	  }

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

  public void add_new_row_for_property (Persona? p, string prop_name, string? type = null) {
    /* Somehow, I need to ensure that p is the main/default/first persona */
    Persona persona = null;
    if (contact != null) {
      if (p == null) {
        persona = new FakePersona (this.store, contact);
        writable_personas[persona.uid] = new HashMap<string, Field?> ();
      } else {
        persona = p;
      }
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
    container_grid.show_all ();
  }

  // Creates the contact's current avatar in a big button on top of the Editor
  private void create_avatar_button () {
    this.avatar = new Avatar (PROFILE_SIZE, this.contact);

    var button = new Button ();
    button.get_accessible ().set_name (_("Change avatar"));
    button.image = this.avatar;
    button.clicked.connect (on_avatar_button_clicked);

    this.container_grid.attach (button, 0, 0, 1, 3);
  }

  // Show the avatar popover when the avatar is clicked
  private void on_avatar_button_clicked (Button avatar_button) {
    var popover = new AvatarSelector (avatar_button, this.contact);
    popover.set_avatar.connect ( (icon) =>  {
        this.avatar.set_data ("value", icon);
        this.avatar.set_data ("changed", true);

        Gdk.Pixbuf? a_pixbuf = null;
        try {
          var stream = (icon as LoadableIcon).load (PROFILE_SIZE, null);
          a_pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, PROFILE_SIZE, PROFILE_SIZE, true);
        } catch {
        }

        this.avatar.set_pixbuf (a_pixbuf);
      });
    popover.show();
  }

  public bool avatar_changed () {
    return this.avatar.get_data<bool> ("changed");
  }

  public Value get_avatar_value () {
    GLib.Icon icon = this.avatar.get_data<GLib.Icon> ("value");
    Value v = Value (icon.get_type ());
    v.set_object (icon);
    return v;
  }

  // Creates the big name entry on the top
  private void create_name_entry () {
    this.name_entry = new Entry ();
    this.name_entry.hexpand = true;
    this.name_entry.valign = Align.CENTER;
    this.name_entry.placeholder_text = _("Add name");
    this.name_entry.set_data ("changed", false);

    if (this.contact != null)
        this.name_entry.text = this.contact.individual.display_name;

    /* structured name change */
    this.name_entry.changed.connect (() => {
        this.name_entry.set_data ("changed", true);
      });

    this.container_grid.attach (this.name_entry, 1, 0, 3, 3);
  }

  public bool name_changed () {
    return this.name_entry.get_data<bool> ("changed");
  }

  public Value get_full_name_value () {
    Value v = Value (typeof (string));
    v.set_string (this.name_entry.get_text ());
    return v;
  }
}
