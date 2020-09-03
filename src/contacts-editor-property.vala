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

using Gtk;
using Folks;
using Gee;


public class Contacts.BirthdayEditor : Gtk.Dialog {
  private SpinButton day_spin;
  private ComboBoxText month_combo;
  private SpinButton year_spin;
  public bool is_set { get; set; default = false; }

  public signal void changed ();
  delegate void AdjustingDateFn ();

  public DateTime get_birthday () {
    return new DateTime.local (year_spin.get_value_as_int (),
    month_combo.get_active () + 1,
    day_spin.get_value_as_int (),
    0, 0, 0).to_utc ();
  }

  public BirthdayEditor (Window window, DateTime birthday) {
    Object (transient_for: window, use_header_bar: 1);
    day_spin = new SpinButton.with_range (1.0, 31.0, 1.0);
    day_spin.set_digits (0);
    day_spin.numeric = true;
    day_spin.set_value ((double)birthday.to_local ().get_day_of_month ());

    month_combo = new ComboBoxText ();
    var january = new DateTime.local (1, 1, 1, 1, 1, 1);
    for (int i = 0; i < 12; i++) {
      var month = january.add_months (i);
      month_combo.append_text (month.format ("%B"));
    }
    month_combo.set_active (birthday.to_local ().get_month () - 1);
    month_combo.hexpand = true;

    year_spin = new SpinButton.with_range (1800, 3000, 1);
    year_spin.set_digits (0);
    year_spin.numeric = true;
    year_spin.set_value ((double)birthday.to_local ().get_year ());

    // Create grid and labels
    Box box = new Box (Orientation.VERTICAL, 12);
    Grid grid = new Grid ();
    grid.set_column_spacing (12);
    grid.set_row_spacing (12);
    Label day = new Label(_("Day"));
    day.set_halign (Align.END);
    grid.attach (day, 0, 0);
    grid.attach (day_spin, 1, 0);
    Label month = new Label(_("Month"));
    month.set_halign (Align.END);
    grid.attach (month, 0, 1);
    grid.attach (month_combo, 1, 1);
    Label year = new Label(_("Year"));
    year.set_halign (Align.END);
    grid.attach (year, 0, 2);
    grid.attach (year_spin, 1, 2);
    box.pack_start (grid);

    var content = this.get_content_area ();
    content.set_valign (Align.CENTER);
    content.add (box);

    this.title = _("Change Address Book");
    add_buttons (_("Set"), ResponseType.OK,
                      _("Cancel"), ResponseType.CANCEL,
                      null);
    var ok_button = this.get_widget_for_response (ResponseType.OK);
    ok_button.get_style_context ().add_class ("suggested-action");
    this.response.connect ((id) => {
      switch (id) {
        case ResponseType.OK:
          this.is_set = true;
          changed ();
          break;
        case ResponseType.CANCEL:
          break;
      }
      this.destroy ();
    });

    box.margin = 12;
    box.show_all ();

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

    /* adjusting day_spin value using selected month/year constraints*/
    fn ();

    month_combo.changed.connect (() => {
      /* adjusting day_spin value using selected month constraints*/
      fn ();
    });
    year_spin.value_changed.connect (() => {
      /* adjusting day_spin value using selected year constraints*/
      fn ();
    });
  }
}

public class Contacts.AddressEditor : Box {
  private Entry? entries[7];  /* must be the number of elements in postal_element_props */

  private const string[] postal_element_props = {"street", "extension", "locality", "region", "postal_code", "po_box", "country"};
  private static string[] postal_element_names = {_("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

  public signal void changed ();

  public AddressEditor (PostalAddressFieldDetails details) {
    set_hexpand (true);
    set_orientation (Orientation.VERTICAL);

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

      var entry = entries[i];
      var prop_name = AddressEditor.postal_element_props[i];
      entries[i].changed.connect (() => {
        details.value.set (prop_name, entry.get_text ());
        changed ();
      });
    }
  }

  public bool is_empty () {
    foreach (var entry in entries) {
      if (entry.get_text () != "") {
        return false;
      }
    }
    return true;
  }

  public override void grab_focus () {
    entries[0].grab_focus ();
  }
}

public class Contacts.EditorPropertyRow : ListBoxRow {
  public bool is_empty { get; set; default = true; }
  public bool is_removed { get; set; default = false; }
  public string ptype { get; private set; }
  public Box container;
  public Box header;
  public Revealer revealer;

  construct {
    this.revealer = new Revealer ();
    //TODO: bind orientation property to available space
    var box = new Box (Orientation.VERTICAL, 6);
    box.set_valign (Align.START);
    box.set_can_focus (false);
    this.container = new Box (Orientation.HORIZONTAL, 6);
    this.container.set_can_focus (false);
    this.header = new Box (Orientation.HORIZONTAL, 6);
    this.header.set_can_focus (false);
    box.pack_start (this.header);
    box.pack_end (this.container);
    this.set_activatable (false);
    this.set_selectable (false);
    this.set_can_focus (false);
    box.margin = 12;
    this.revealer.add (box);
    add (this.revealer);
    this.get_style_context ().add_class ("editor-property-row");
    this.revealer.bind_property ("reveal-child", this, "is-removed", BindingFlags.INVERT_BOOLEAN);
  }

  public EditorPropertyRow (string type) {
    this.ptype = type;
  }

  // This hides the widget with an animation and then destroys it
  public new void remove () {
    this.revealer.set_reveal_child (false);
    // Remove the seperator during the animation to make it look a little better
    Timeout.add (this.revealer.get_transition_duration ()/2, () => {
      this.set_header (null);
      return false;
    });

    this.revealer.notify["child-revealed"].connect ( () => {
      this.destroy ();
    });
  }

  public void show_with_animation (bool animate = true) {
    if (!animate) {
      var duration = this.revealer.get_transition_duration ();
      this.revealer.set_reveal_child (true);
      this.revealer.set_transition_duration (duration);
      this.show_all ();
    } else {
      this.show_all ();
      this.revealer.set_reveal_child (true);
    }
  }

  public void add_base_label (string label) {
    var title_label = new Label (label);
    title_label.set_hexpand (false);
    title_label.set_halign (Align.START);
    title_label.margin_end = 6;
    this.header.pack_start (title_label);
  }

  public void add_base_combo (Set<AbstractFieldDetails> details_set, string label, TypeSet combo_type, AbstractFieldDetails details) {
    var title_label = new Label (label);
    title_label.set_halign (Align.START);
    this.header.pack_start (title_label);
    TypeCombo combo = new TypeCombo (combo_type);
    combo.set_hexpand (false);
    combo.set_active_from_field_details (details);
    this.header.pack_start (combo);

    combo.changed.connect (() => {
      combo.active_descriptor.save_to_field_details(details);
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property phone changed");
    });
  }

  //FIXME: create only one add_base_entry
  public void add_base_entry_email (Set<AbstractFieldDetails> details_set,
                                    EmailFieldDetails details,
                                    string placeholder) {
    var value_entry = new Entry ();
    value_entry.set_input_purpose (InputPurpose.EMAIL);
    value_entry.placeholder_text = placeholder;
    value_entry.set_text (details.value);
    value_entry.set_hexpand (true);
    this.container.pack_start (value_entry);

    this.is_empty = details.value == "";

    value_entry.changed.connect (() => {
      details.value = value_entry.get_text ();
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property email changed");
      this.is_empty = value_entry.get_text () == "";
    });
  }

  public void add_base_entry_phone (Set<AbstractFieldDetails> details_set,
                                    PhoneFieldDetails details,
                                    string placeholder) {
    var value_entry = new Entry ();
    value_entry.set_input_purpose (InputPurpose.PHONE);
    value_entry.placeholder_text = placeholder;
    value_entry.set_text (details.value);
    value_entry.set_hexpand (true);
    this.container.pack_start (value_entry);

    this.is_empty = details.value == "";

    value_entry.changed.connect (() => {
      details.value = value_entry.get_text ();
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property type changed");

      this.is_empty = value_entry.get_text () == "";
    });
  }

  public void add_base_entry_url (Set<AbstractFieldDetails> details_set,
                                  UrlFieldDetails details,
                                  string placeholder) {
    var value_entry = new Entry ();
    value_entry.placeholder_text = placeholder;
    value_entry.set_input_purpose (InputPurpose.URL);
    value_entry.set_text (details.value);
    value_entry.set_hexpand (true);
    this.container.pack_start (value_entry);

    this.is_empty = details.value == "";

    value_entry.changed.connect (() => {
      details.value = value_entry.get_text ();
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property type changed");

      this.is_empty = value_entry.get_text () == "";
    });
  }

  public void add_base_delete (Set<AbstractFieldDetails> details_set,
                               AbstractFieldDetails details) {
    var delete_button = new Button.from_icon_name ("user-trash-symbolic");
    delete_button.get_accessible ().set_name (_("Delete field"));
    delete_button.set_valign (Align.START);
    this.bind_property ("is-empty", delete_button, "sensitive", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
    this.container.pack_end (delete_button, false);


    delete_button.clicked.connect (() => {
      debug ("Property removed");
      this.remove ();
      details_set.remove (details);
    });
  }
}

/**
 * A widget representing a property of a persona in the editor {@link Contact}.
 * We can have more then one property in one properity e.g. Emails therefore we need to return a List
 */
public class Contacts.EditorProperty : ArrayList<EditorPropertyRow> {
  public bool writeable { get; private set; default = false; }

  public EditorProperty (Persona persona, string property_name, bool only_new = false) {
    foreach (var s in persona.writeable_properties) {
      if (s == property_name) {
        this.writeable = true;
        break;
      }
    }

    create_for_property (persona, property_name, only_new);
  }

  private void create_for_property (Persona p, string prop_name, bool only_new) {
    switch (prop_name) {
      case "email-addresses":
        var details = p as EmailDetails;
        if (details != null) {
          var emails = Utils.sort_fields<EmailFieldDetails>(details.email_addresses);
          if (!only_new)
            foreach (var email in emails) {
              add (create_for_email (details.email_addresses, email));
            }
          if (this.writeable)
            add (create_for_email (details.email_addresses));
        }
        break;
      case "phone-numbers":
        var details = p as PhoneDetails;
        if (details != null) {
          var phones = Utils.sort_fields<PhoneFieldDetails>(details.phone_numbers);
          if (!only_new)
            foreach (var phone in phones) {
              add (create_for_phone (details.phone_numbers, phone));
            }
          if (this.writeable)
            add (create_for_phone (details.phone_numbers));
        }
        break;
      case "urls":
        var details = p as UrlDetails;
        if (details != null) {
          var urls = Utils.sort_fields<UrlFieldDetails>(details.urls);
          if (!only_new)
            foreach (var url in urls) {
              add (create_for_url (details.urls, url));
            }
          add (create_for_url (details.urls));
        }
        break;
      case "nickname":
        var name_details = p as NameDetails;
        if (name_details != null && name_details.nickname != null && !only_new) {
          add (create_for_nick (name_details));
        }
        break;
      case "birthday":
        var birthday_details = p as BirthdayDetails;
        if (birthday_details != null && !only_new) {
          add (create_for_birthday (birthday_details));
        }
        break;
      case "notes":
        var note_details = p as NoteDetails;
        if (note_details != null) {
          if (!only_new)
            foreach (var note in note_details.notes) {
              add (create_for_note (note_details.notes, note));
            }
          if (this.writeable)
            add (create_for_note (note_details.notes));
        }
        break;
      case "postal-addresses":
        var address_details = p as PostalAddressDetails;
        if (address_details != null) {
          if (!only_new)
            foreach (var addr in address_details.postal_addresses) {
              add (create_for_address (address_details.postal_addresses, addr));
            }
          if (this.writeable)
            add (create_for_address (address_details.postal_addresses));
        }
        break;
    }
  }

  private EditorPropertyRow create_for_email (Set<AbstractFieldDetails> set, EmailFieldDetails? details = null) {
    if (details == null) {
      var parameters = new HashMultiMap<string, string> ();
      parameters["type"] = "PERSONAL";
      var new_details = new EmailFieldDetails ("", parameters);
      set.add(new_details);
      details = new_details;
    }
    var box = new EditorPropertyRow ("email-addresses");
    box.add_base_combo (set, _("Email address"), TypeSet.email, details);
    box.add_base_entry_email (set, details, _("Add email"));
    box.add_base_delete (set, details);

    box.sensitive = this.writeable;
    return box;
  }

  private EditorPropertyRow create_for_phone (Set<AbstractFieldDetails> set, PhoneFieldDetails? details = null) {
    if (details == null) {
      var parameters = new HashMultiMap<string, string> ();
      parameters["type"] = "CELL";
      var new_details = new PhoneFieldDetails ("", parameters);
      set.add(new_details);
      details = new_details;
    }

    var box = new EditorPropertyRow ("phone-numbers");
    box.add_base_combo (set, _("Phone number"), TypeSet.phone, details);
    box.add_base_entry_phone (set, details, _("Add number"));
    box.add_base_delete (set, details);

    box.sensitive = this.writeable;
    return box;
  }

  // TODO: add support for different types of urls
  private EditorPropertyRow create_for_url (Set<AbstractFieldDetails> set, UrlFieldDetails? details = null) {
    if (details == null) {
      var parameters = new HashMultiMap<string, string> ();
      parameters["type"] = "PERSONAL";
      var new_details = new UrlFieldDetails ("", parameters);
      set.add(new_details);
      details = new_details;
    }

    var box = new EditorPropertyRow ("urls");
    box.add_base_label (_("Website"));
    box.add_base_entry_url (set, details, _("https://example.com"));
    box.add_base_delete (set, details);

    box.sensitive = this.writeable;
    return box;
  }

  private EditorPropertyRow create_for_nick (NameDetails details) {
    var box = new EditorPropertyRow ("nickname");
    box.add_base_label (_("Nickname"));

    var value_entry = new Entry ();
    value_entry.set_text (details.nickname);
    value_entry.set_hexpand (true);
    box.container.pack_start (value_entry);

    value_entry.changed.connect (() => {
      details.nickname = value_entry.get_text ();
      debug ("Nickname changed");
      box.is_empty = value_entry.get_text () == "";
    });

    box.sensitive = this.writeable;
    return box;
  }

  // TODO: support different types of nodes
  private EditorPropertyRow create_for_note (Set<NoteFieldDetails> details_set,
                                             NoteFieldDetails? details = null) {
    if (details == null) {
      var parameters = new HashMultiMap<string, string> ();
      parameters["type"] = "PERSONAL";
      var new_details = new NoteFieldDetails ("", parameters);
      details_set.add(new_details);
      details = new_details;
    }
    var box = new EditorPropertyRow ("notes");
    box.add_base_label (_("Note"));

    var sw = new ScrolledWindow (null, null);
    sw.set_shadow_type (ShadowType.OUT);
    sw.set_size_request (-1, 100);
    var value_text = new TextView ();
    value_text.get_buffer ().set_text (details.value);
    value_text.set_hexpand (true);
    sw.add (value_text);
    box.container.pack_start (sw);

    box.add_base_delete (details_set, details);

    value_text.get_buffer ().changed.connect (() => {
      TextIter start, end;
      value_text.get_buffer ().get_start_iter (out start);
      value_text.get_buffer ().get_end_iter (out end);
      details.value = value_text.get_buffer ().get_text (start, end, true);
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property changed");
      box.is_empty = details.value == "";
    });

    box.sensitive = this.writeable;
    return box;
  }

  private EditorPropertyRow create_for_birthday (BirthdayDetails? details) {
    DateTime date;
    if (details.birthday == null) {
      date = new DateTime.now ();
    } else {
      date = details.birthday;
    }

    var box = new EditorPropertyRow ("birthday");
    box.add_base_label (_("Birthday"));

    var button = new Button.with_label (_("Set Birthday"));
    box.container.pack_start (button);

    button.clicked.connect (() => {
      Window parent_window = button.get_toplevel () as Window;
      if (parent_window != null) {
        var dialog = new BirthdayEditor (parent_window, date);

        dialog.changed.connect (() => {
          if (dialog.is_set) {
            details.birthday = dialog.get_birthday ();
            button.set_label (details.birthday.to_local ().format ("%x"));
            box.is_empty = false;
          }
        });
        dialog.show_all ();
      }
    });

    box.is_empty = details.birthday == null;

    var delete_button = new Button.from_icon_name ("user-trash-symbolic");
    delete_button.get_accessible ().set_name (_("Delete field"));
    delete_button.set_valign (Align.START);
    box.bind_property ("is-empty", delete_button, "sensitive", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
    box.container.pack_end (delete_button, false);

    delete_button.clicked.connect (() => {
      debug ("Birthday removed");
      details.birthday = null;
      box.is_empty = true;
      button.set_label (_("Set Birthday"));
    });

    box.sensitive = this.writeable;
    return box;
  }

  private EditorPropertyRow create_for_address (Set<PostalAddressFieldDetails> details_set,
                                                PostalAddressFieldDetails? details = null) {
    if (details == null) {
      var parameters = new HashMultiMap<string, string> ();
      parameters["type"] = "HOME";
      var address = new PostalAddress(null, null, null, null, null, null, null, null, null);
      var new_details = new PostalAddressFieldDetails (address, parameters);
      details_set.add(new_details);
      details = new_details;
    }
    var box = new EditorPropertyRow ("postal-addresses");
    box.add_base_combo (details_set, _("Address"), TypeSet.general, details);

    var value_address = new AddressEditor (details);
    box.container.pack_start (value_address);

    box.is_empty = value_address.is_empty ();

    box.add_base_delete (details_set, details);

    value_address.changed.connect (() => {
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Address changed");
      box.is_empty = value_address.is_empty ();
    });

    box.sensitive = this.writeable;
    return box;
  }
}
