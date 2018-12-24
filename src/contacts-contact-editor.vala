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

  private weak Widget focus_widget;

  [GtkChild]
  private MenuButton add_detail_button;

  [GtkChild]
  public Button linked_button;

  [GtkChild]
  public Button remove_button;

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
    this.container_grid.size_allocate.connect(on_container_grid_size_allocate);
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
    foreach (var p in this.contact.individual.personas) {
      foreach (var prop in p.writeable_properties) {
        var field = add_edit_row (p, prop);
        if (field != null)
          add_field (field);
      }
    }
  }

  private void fill_in_empty () {
    foreach (var prop in DEFAULT_PROPS_NEW_CONTACT) {
      var tok = prop.split (".");
      var field = add_edit_row (null, tok[0], true, tok[1].up ());
      if (field != null)
        add_field (field);
    }

    this.focus_widget = this.name_widget;
  }

  PropertyField? add_edit_row (Persona? p, string prop_name, bool add_empty = false, string? type = null) {
    switch (prop_name) {
    case "email-addresses":
      if (add_empty)
          return new EditableEmailsField.empty ();
      if (EmailsField.should_show (p))
        return new EditableEmailsField (p);
      break;

    case "phone-numbers":
      if (add_empty)
          return new EditablePhoneNrsField.empty ();
      if (PhoneNrsField.should_show (p))
        return new EditablePhoneNrsField (p);
      break;

    case "urls":
      if (add_empty)
        return new EditableUrlsField.empty ();
      if (UrlsField.should_show (p))
        return new EditableUrlsField (p);
      break;

    case "nickname":
      if (add_empty)
        return new EditableNicknameField.empty ();
      if (NicknameField.should_show (p))
        return new EditableNicknameField (p);
      break;

    case "birthday":
      if (add_empty)
        return new EditableBirthdayField.empty ();
      if (BirthdayField.should_show (p))
        return new EditableBirthdayField (p);
      break;

    case "notes":
      if (add_empty)
          return new EditableNotesField.empty ();
      if (NotesField.should_show (p))
        return new EditableNotesField (p);
      break;

    case "postal-addresses":
      if (add_empty)
        return new EditablePostalAddressesField.empty ();
      if (PostalAddressesField.should_show (p))
        return new EditablePostalAddressesField (p);
      break;
    }

    return null;
  }

  private void on_container_grid_size_allocate (Allocation alloc) {
    if (this.focus_widget != null && this.focus_widget is Widget) {
      this.focus_widget.grab_focus ();
      this.focus_widget = null;
    }
  }

  public async void save_changes () throws Error {
    for (uint i = 0; i < this.fields.get_n_items (); i++) {
      var field = this.fields.get_item (i) as EditableProperty;
      if (field != null) {
        yield field.save_changes ();
        debug ("Successfully saved property '%s'", field.property_name);
      }
    }

    if (name_changed ()) {
      var v = get_full_name_value ();
      yield this.contact.set_individual_property ("full-name", v);
      debug ("Successfully saved name");
      /*XXX*/
      /* display_name_changed (v.get_string ()); */
    }

    if (avatar_changed ()) {
      var v = get_avatar_value ();
      yield this.contact.set_individual_property ("avatar", v);
      debug ("Successfully saved avatar");
    }
  }

  public HashTable<string, Value?> create_details_for_new_contact () {
    var details = new HashTable<string, Value?> (str_hash, str_equal);

    // Collect the details from the editor
    if (name_changed ())
      details["full-name"] = get_full_name_value ();

    if (avatar_changed ())
      details["avatar"] = get_avatar_value ();

    for (uint i = 0; i < this.fields.get_n_items (); i++) {
      var field = this.fields.get_item (i) as EditableProperty;

      if (field != null)
        details[field.property_name] = field.create_value ();
    }

    return details;
  }

  public void add_new_row_for_property (Persona? p, string prop_name, string? type = null) {
  }

  // Creates the contact's current avatar in a big button on top of the Editor
  private void create_avatar_button () {
    this.avatar_widget = new Avatar (PROFILE_SIZE, this.contact);

    var button = new Button ();
    button.get_accessible ().set_name (_("Change avatar"));
    button.image = (Avatar) this.avatar_widget;
    button.clicked.connect (on_avatar_button_clicked);

    attach_avatar_widget (button);
  }

  // Show the avatar popover when the avatar is clicked
  private void on_avatar_button_clicked (Button avatar_button) {
    var popover = new AvatarSelector (avatar_button, this.contact);
    popover.set_avatar.connect ( (icon) =>  {
        this.avatar_widget.set_data ("value", icon);
        this.avatar_widget.set_data ("changed", true);

        Gdk.Pixbuf? a_pixbuf = null;
        try {
          var stream = (icon as LoadableIcon).load (PROFILE_SIZE, null);
          a_pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, PROFILE_SIZE, PROFILE_SIZE, true);
        } catch {
        }

        ((Avatar) this.avatar_widget).set_pixbuf (a_pixbuf);
      });
    popover.show();
  }

  public bool avatar_changed () {
    return this.avatar_widget.get_data<bool> ("changed");
  }

  public Value get_avatar_value () {
    GLib.Icon icon = this.avatar_widget.get_data<GLib.Icon> ("value");
    Value v = Value (icon.get_type ());
    v.set_object (icon);
    return v;
  }

  // Creates the big name entry on the top
  private void create_name_entry () {
    var name_entry = new Entry ();
    name_entry.placeholder_text = _("Add name");
    name_entry.set_data ("changed", false);
    set_name_widget (name_entry);

    if (this.contact != null)
        name_entry.text = this.contact.individual.display_name;

    /* structured name change */
    name_entry.changed.connect (() => {
        name_entry.set_data ("changed", true);
      });
  }

  public bool name_changed () {
    return this.name_widget.get_data<bool> ("changed");
  }

  public Value get_full_name_value () {
    Value v = Value (typeof (string));
    v.set_string (((Entry) this.name_widget).text);
    return v;
  }
}
