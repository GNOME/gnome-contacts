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

public class Contacts.BirthdayEditor : Gtk.Dialog {

  private unowned Gtk.SpinButton day_spin;
  private unowned Gtk.ComboBoxText month_combo;
  private unowned Gtk.SpinButton year_spin;

  public bool is_set { get; set; default = false; }

  public signal void changed ();

  construct {
    // The grid that will contain the Y/M/D fields
    var grid = new Gtk.Grid ();
    grid.column_spacing = 12;
    grid.row_spacing = 12;
    grid.add_css_class ("contacts-editor-birthday");
    ((Gtk.Box) this.get_content_area ()).append (grid);

    // Day
    var d_spin = new Gtk.SpinButton.with_range (1.0, 31.0, 1.0);
    d_spin.digits = 0;
    d_spin.numeric = true;
    this.day_spin = d_spin;

    // Month
    var m_combo = new Gtk.ComboBoxText ();
    var january = new DateTime.local (1, 1, 1, 1, 1, 1);
    for (int i = 0; i < 12; i++) {
      var month = january.add_months (i);
      m_combo.append_text (month.format ("%B"));
    }
    m_combo.hexpand = true;
    this.month_combo = m_combo;

    // Year
    var y_spin = new Gtk.SpinButton.with_range (1800, 3000, 1);
    y_spin.set_digits (0);
    y_spin.numeric = true;
    this.year_spin = y_spin;

    // Create grid and labels
    Gtk.Label day = new Gtk.Label (_("Day"));
    day.set_halign (Gtk.Align.END);
    grid.attach (day, 0, 0);
    grid.attach (day_spin, 1, 0);
    Gtk.Label month = new Gtk.Label (_("Month"));
    month.set_halign (Gtk.Align.END);
    grid.attach (month, 0, 1);
    grid.attach (month_combo, 1, 1);
    Gtk.Label year = new Gtk.Label (_("Year"));
    year.set_halign (Gtk.Align.END);
    grid.attach (year, 0, 2);
    grid.attach (year_spin, 1, 2);

    this.title = _("Change Birthday");
    add_buttons (_("Set"), Gtk.ResponseType.OK,
                 _("Cancel"), Gtk.ResponseType.CANCEL,
                 null);
    var ok_button = this.get_widget_for_response (Gtk.ResponseType.OK);
    ok_button.add_css_class ("suggested-action");
    this.response.connect ((id) => {
      switch (id) {
        case Gtk.ResponseType.OK:
          this.is_set = true;
          changed ();
          break;
        case Gtk.ResponseType.CANCEL:
          break;
      }
      this.destroy ();
    });
  }

  public BirthdayEditor (Gtk.Window window, DateTime birthday) {
    Object (transient_for: window, use_header_bar: 1);

    this.day_spin.set_value ((double) birthday.get_day_of_month ());
    this.month_combo.set_active (birthday.get_month () - 1);
    this.year_spin.set_value ((double) birthday.get_year ());

    update_date ();
    month_combo.changed.connect (() => {
      update_date ();
    });
    year_spin.value_changed.connect (() => {
      update_date ();
    });
  }

  public GLib.DateTime get_birthday () {
    return new GLib.DateTime.local (year_spin.get_value_as_int (),
                                    month_combo.get_active () + 1,
                                    day_spin.get_value_as_int (),
                                    0, 0, 0).to_utc ();
  }

  private void update_date() {
    const int[] month_of_31 = {3, 5, 8, 10};

    if (this.month_combo.get_active () in month_of_31) {
      this.day_spin.set_range (1, 30);
    } else if (this.month_combo.get_active () == 1) {
      if (this.year_spin.get_value_as_int () % 400 == 0 ||
          (this.year_spin.get_value_as_int () % 4 == 0 &&
           this.year_spin.get_value_as_int () % 100 != 0)) {
        this.day_spin.set_range (1, 29);
      } else {
        this.day_spin.set_range (1, 28);
      }
    } else {
      this.day_spin.set_range (1, 31);
    }
  }
}

public class Contacts.AddressEditor : Gtk.Box {
  private Gtk.Entry? entries[7];  /* must be the number of elements in postal_element_props */

  private const string[] postal_element_props = {"street", "extension", "locality", "region", "postal_code", "po_box", "country"};
  private static string[] postal_element_names = {_("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

  public signal void changed ();

  construct {
    this.add_css_class ("contacts-editor-address");

    this.hexpand = true;
    this.orientation = Gtk.Orientation.VERTICAL;
  }

  public AddressEditor (PostalAddressFieldDetails details) {
    for (int i = 0; i < entries.length; i++) {
      string postal_part;
      details.value.get (AddressEditor.postal_element_props[i], out postal_part);

      this.entries[i] = new Gtk.Entry ();
      this.entries[i].hexpand = true;
      this.entries[i].placeholder_text = AddressEditor.postal_element_names[i];
      this.entries[i].add_css_class ("flat");

      if (postal_part != null)
        this.entries[i].text = postal_part;

      append (this.entries[i]);

      var prop_name = AddressEditor.postal_element_props[i];
      entries[i].changed.connect (() => {
        details.value.set (prop_name, this.entries[i].text);
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
}

/**
 * Basic widget to show a single property of a contact (for example an email
 * address, a birthday, ...). It can show itself using a GtkRevealer animation.
 *
 * To edit the value of the property, you should supply a widget and set it as
 * the main widget.
 */
public class Contacts.EditorPropertyRow : Adw.Bin {

  private unowned Gtk.Revealer revealer;
  private unowned Gtk.ListBox listbox;

  public bool is_empty { get; set; default = true; }
  public bool is_removed { get; set; default = false; }
  public bool removable { get; set; default = false; }

  /** Internal type name of the property */
  public string ptype { get; construct; }

  construct {
    var _revealer = new Gtk.Revealer ();
    _revealer.bind_property ("reveal-child", this, "is-removed",
                             BindingFlags.BIDIRECTIONAL | BindingFlags.INVERT_BOOLEAN);
    this.child = _revealer;
    this.revealer = _revealer;

    var list_box = new Gtk.ListBox ();
    this.listbox = list_box;
    this.listbox.selection_mode = Gtk.SelectionMode.NONE;
    this.listbox.activate_on_single_click = true;
    this.listbox.add_css_class ("boxed-list");
    this.listbox.add_css_class ("contacts-editor-property");
    this.revealer.set_child (listbox);
  }

  public EditorPropertyRow (string type) {
    Object (ptype: type);
  }

  public void show_with_animation (bool animate = true) {
    if (!animate) {
      var duration = this.revealer.get_transition_duration ();
      this.revealer.set_reveal_child (true);
      this.revealer.set_transition_duration (duration);
    } else {
      this.revealer.set_reveal_child (true);
    }
  }

  // This hides the widget with an animation and then destroys it
  public void remove () {
    debug ("Property %s is removed", this.ptype);

    this.revealer.set_reveal_child (false);

    // Remove the separator during the animation to make it look a little better
    Timeout.add (this.revealer.get_transition_duration ()/2, () => {
      return false;
    });

    this.revealer.notify["child-revealed"].connect (() => {
      this.destroy ();
    });
  }

  /**
   * Setter for the main widget, which can be used to actually edit the property
   */
  public void set_main_widget (Gtk.Widget widget, bool add_icon = true) {
    var row = new Gtk.ListBoxRow ();
    row.focusable = false;

    var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    widget.hexpand = true;
    row.set_child (box);

    // Start with the icon (if known)
    if (add_icon) {
      unowned var icon_name = Utils.get_icon_name_for_property (this.ptype);
      if (icon_name != null) {
        var icon = new Gtk.Image.from_icon_name (icon_name);
        icon.add_css_class ("contacts-property-icon");
        icon.tooltip_text = Utils.get_display_name_for_property (this.ptype);
        box.prepend (icon);
      }
    }

    // Set the actual widget
    // (mimic Adw.ActionRow's "activatable-widget")
    box.append (widget);
    this.listbox.row_activated.connect ((activated_row) => {
      if (row == activated_row)
        widget.mnemonic_activate (false);
    });

    // Add a delete buton if needed
    if (this.removable) {
      var delete_button = new Gtk.Button.from_icon_name ("user-trash-symbolic");
      delete_button.tooltip_text = _("Delete field");
      this.bind_property ("is-empty", delete_button, "sensitive", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);

      delete_button.clicked.connect ((b) => { this.remove (); });

      box.append (delete_button);
    }

    this.listbox.append (row);
  }

  /**
   * Wrapper around set_main_widget() with some extra styling for GtkEntries,
   * as well as making sure the "is-empty" property is updated.
   */
  public Gtk.Entry set_main_entry (string text, string? placeholder = null) {
    var entry = new Gtk.Entry ();
    entry.text = text;
    entry.placeholder_text = placeholder;
    entry.add_css_class ("flat");
    entry.add_css_class ("contacts-editor-main-entry");
    // Set the icon as part of the GtkEntry, to avoid it being outside of the
    // margin
    unowned var icon_name = Utils.get_icon_name_for_property (this.ptype);
    if (icon_name != null) {
      entry.primary_icon_name = icon_name;
      entry.primary_icon_tooltip_text = Utils.get_display_name_for_property (this.ptype);
    }
    this.set_main_widget (entry, false);

    this.is_empty = (text == "");
    entry.changed.connect (() => {
      this.is_empty = (entry.text == "");
    });

    return entry;
  }

  // Adds an extra row for a type combo, to choose between e.g. "Home" or "Work"
  public void add_type_combo (Gee.Set<AbstractFieldDetails> details_set,
                              TypeSet combo_type,
                              AbstractFieldDetails details) {
    var row = new TypeComboRow (combo_type);
    row.title = _("Label");
    row.set_selected_from_field_details (details);
    this.listbox.append (row);

    row.notify["selected-item"].connect ((obj, pspec) => {
      unowned var descr = row.selected_descriptor;
      descr.save_to_field_details (details);
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property phone changed");
    });
  }
}

/**
 * A widget representing a property of a persona in the editor {@link Contact}.
 *
 * We can have more then one field in a single property
 * (for example: emails, phone nrs, ...), so it implements a
 * {@link GLib.ListModel}.
 */
public class Contacts.EditorProperty : Object, ListModel {

  private GenericArray<EditorPropertyRow> rows;

  public bool writeable { get; private set; default = false; }

  construct {
    this.rows = new GenericArray<EditorPropertyRow> (1);
  }

  public EditorProperty (Persona persona, string property_name, bool only_new = false) {
    foreach (unowned string s in persona.writeable_properties) {
      if (s == property_name) {
        this.writeable = true;
        break;
      }
    }

    create_for_property (persona, property_name, only_new);
  }

  public Object? get_item (uint i) {
    if (i > this.rows.length)
      return null;

    return this.rows[i];
  }

  public uint get_n_items () {
    return this.rows.length;
  }

  public GLib.Type get_item_type () {
    return typeof (EditorPropertyRow);
  }

  private void create_for_property (Persona p, string prop_name, bool only_new) {
    switch (prop_name) {
      case "email-addresses":
        unowned var details = p as EmailDetails;
        if (details != null) {
          var emails = Utils.sort_fields<EmailFieldDetails>(details.email_addresses);
          if (!only_new)
            foreach (var email in emails) {
              this.rows.add (create_for_email (details.email_addresses, email));
            }
          if (this.writeable)
            this.rows.add (create_for_email (details.email_addresses));
        }
        break;
      case "phone-numbers":
        unowned var details = p as PhoneDetails;
        if (details != null) {
          var phones = Utils.sort_fields<PhoneFieldDetails>(details.phone_numbers);
          if (!only_new)
            foreach (var phone in phones) {
              this.rows.add (create_for_phone (details.phone_numbers, phone));
            }
          if (this.writeable)
            this.rows.add (create_for_phone (details.phone_numbers));
        }
        break;
      case "urls":
        unowned var details = p as UrlDetails;
        if (details != null) {
          var urls = Utils.sort_fields<UrlFieldDetails>(details.urls);
          if (!only_new)
            foreach (var url in urls) {
              this.rows.add (create_for_url (details.urls, url));
            }
          this.rows.add (create_for_url (details.urls));
        }
        break;
      case "nickname":
        unowned var name_details = p as NameDetails;
        if (name_details != null && name_details.nickname != null && !only_new) {
          this.rows.add (create_for_nick (name_details));
        }
        break;
      case "birthday":
        unowned var birthday_details = p as BirthdayDetails;
        if (birthday_details != null && !only_new) {
          this.rows.add (create_for_birthday (birthday_details));
        }
        break;
      case "notes":
        unowned var note_details = p as NoteDetails;
        if (note_details != null) {
          if (!only_new)
            foreach (var note in note_details.notes) {
              this.rows.add (create_for_note (note_details.notes, note));
            }
          if (this.writeable)
            this.rows.add (create_for_note (note_details.notes));
        }
        break;
      case "postal-addresses":
        unowned var address_details = p as PostalAddressDetails;
        if (address_details != null) {
          if (!only_new)
            foreach (var addr in address_details.postal_addresses) {
              this.rows.add (create_for_address (address_details.postal_addresses, addr));
            }
          if (this.writeable)
            this.rows.add (create_for_address (address_details.postal_addresses));
        }
        break;
    }
  }

  private EditorPropertyRow create_for_email (Gee.Set<AbstractFieldDetails> details_set,
                                              EmailFieldDetails? details = null) {
    if (details == null) {
      var parameters = new Gee.HashMultiMap<string, string> ();
      parameters["type"] = "PERSONAL";
      var new_details = new EmailFieldDetails ("", parameters);
      details_set.add (new_details);
      details = new_details;
    }

    var box = new EditorPropertyRow ("email-addresses");
    box.sensitive = this.writeable;

    var entry = box.set_main_entry (details.value, _("Add email"));
    entry.set_input_purpose (Gtk.InputPurpose.EMAIL);
    entry.changed.connect (() => {
      details.value = entry.get_text ();
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property email changed");
    });

    box.add_type_combo (details_set, TypeSet.email, details);

    return box;
  }

  private EditorPropertyRow create_for_phone (Gee.Set<AbstractFieldDetails> details_set,
                                              PhoneFieldDetails? details = null) {
    if (details == null) {
      var parameters = new Gee.HashMultiMap<string, string> ();
      parameters["type"] = "CELL";
      var new_details = new PhoneFieldDetails ("", parameters);
      details_set.add (new_details);
      details = new_details;
    }

    var box = new EditorPropertyRow ("phone-numbers");
    box.sensitive = this.writeable;

    var entry = box.set_main_entry (details.value, _("Add phone number"));
    entry.set_input_purpose (Gtk.InputPurpose.PHONE);
    entry.changed.connect (() => {
      details.value = entry.text;
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property type changed");
    });

    box.add_type_combo (details_set, TypeSet.phone, details);

    return box;
  }

  // TODO: add support for different types of urls
  private EditorPropertyRow create_for_url (Gee.Set<AbstractFieldDetails> details_set,
                                            UrlFieldDetails? details = null) {
    if (details == null) {
      var parameters = new Gee.HashMultiMap<string, string> ();
      parameters["type"] = "PERSONAL";
      var new_details = new UrlFieldDetails ("", parameters);
      details_set.add (new_details);
      details = new_details;
    }

    var box = new EditorPropertyRow ("urls");
    box.sensitive = this.writeable;

    var entry = box.set_main_entry (details.value, _("https://example.com"));
    entry.set_input_purpose (Gtk.InputPurpose.URL);
    entry.changed.connect (() => {
      details.value = entry.get_text ();
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property type changed");
    });

    return box;
  }

  private EditorPropertyRow create_for_nick (NameDetails details) {
    var box = new EditorPropertyRow ("nickname");
    box.sensitive = this.writeable;

    var entry = box.set_main_entry (details.nickname, _("Nickname"));
    entry.set_input_purpose (Gtk.InputPurpose.NAME);
    entry.changed.connect (() => {
      details.nickname = entry.text;
      debug ("Nickname changed");
    });

    return box;
  }

  // TODO: support different types of notes
  private EditorPropertyRow create_for_note (Gee.Set<NoteFieldDetails> details_set,
                                             NoteFieldDetails? details = null) {
    if (details == null) {
      var parameters = new Gee.HashMultiMap<string, string> ();
      parameters["type"] = "PERSONAL";
      var new_details = new NoteFieldDetails ("", parameters);
      details_set.add (new_details);
      details = new_details;
    }
    var box = new EditorPropertyRow ("notes");

    var sw = new Gtk.ScrolledWindow ();
    sw.focusable = false;
    sw.has_frame = false;
    sw.set_size_request (-1, 100);
    box.set_main_widget (sw);

    var textview = new Gtk.TextView ();
    textview.get_buffer ().set_text (details.value);
    textview.hexpand = true;
    sw.set_child (textview);

    textview.get_buffer ().changed.connect (() => {
      Gtk.TextIter start, end;
      textview.get_buffer ().get_start_iter (out start);
      textview.get_buffer ().get_end_iter (out end);
      details.value = textview.get_buffer ().get_text (start, end, true);
      // Workaround: we shouldn't do a manual signal
      ((FakeHashSet) details_set).changed ();
      debug ("Property changed");
      box.is_empty = details.value == "";
    });

    box.sensitive = this.writeable;
    return box;
  }

  private EditorPropertyRow create_for_birthday (BirthdayDetails? details) {
    var date = details.birthday ?? new DateTime.now ();

    Gtk.Button button;
    if (details.birthday == null) {
      button = new Gtk.Button.with_label (_("Set Birthday"));
    } else {
      button = new Gtk.Button.with_label (details.birthday.to_local ().format ("%x"));
    }

    var box = new EditorPropertyRow ("birthday");
    box.set_main_widget (button);

    button.clicked.connect (() => {
      unowned var parent_window = button.get_root () as Gtk.Window;
      if (parent_window != null) {
        var dialog = new BirthdayEditor (parent_window, date);

        dialog.changed.connect (() => {
          if (dialog.is_set) {
            details.birthday = dialog.get_birthday ();
            button.set_label (details.birthday.format ("%x"));
            box.is_empty = false;
          }
        });
        dialog.show ();
      }
    });

    box.is_empty = details.birthday == null;

    var delete_button = new Gtk.Button.from_icon_name ("user-trash-symbolic");
    delete_button.tooltip_text = _("Delete field");
    delete_button.set_valign (Gtk.Align.START);
    box.bind_property ("is-empty", delete_button, "sensitive", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
    // box.container.append (delete_button); XXX

    delete_button.clicked.connect (() => {
      debug ("Birthday removed");
      details.birthday = null;
      box.is_empty = true;
      button.set_label (_("Set Birthday"));
    });

    box.sensitive = this.writeable;
    return box;
  }

  private EditorPropertyRow create_for_address (Gee.Set<PostalAddressFieldDetails> details_set,
                                                PostalAddressFieldDetails? details = null) {
    if (details == null) {
      var parameters = new Gee.HashMultiMap<string, string> ();
      parameters["type"] = "HOME";
      var address = new PostalAddress (null, null, null, null, null, null, null, null, null);
      var new_details = new PostalAddressFieldDetails (address, parameters);
      details_set.add (new_details);
      details = new_details;
    }
    var box = new EditorPropertyRow ("postal-addresses");

    var value_address = new AddressEditor (details);
    box.set_main_widget (value_address);
    box.is_empty = value_address.is_empty ();

    box.add_type_combo (details_set, TypeSet.general, details);

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
