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

public errordomain Contacts.SaveError {
  EMPTY_DATA,
  NO_PRIMARY_ADDRESSBOOK,
}

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-contact-editor.ui")]
public class Contacts.Editor.ContactEditor : Grid {

  private const string[] DEFAULT_PROPS_NEW_CONTACT = {
    "email-addresses",
    "phone-numbers",
    "postal-addresses"
  };

  // We have a form with fields for each persona.
  private struct Form {
    Persona? persona; // null iff new contact
    Gee.List<Editor.DetailsEditor> editors;
  }

  // The contact we're editing, or null if creating a new one.
  private Contact? contact;

  private Store store;

  // The first row of the container_grid that is empty.
  private int next_row = 0;

  private Gee.List<Form?> forms = new LinkedList<Form?> ();

  private Editor.DetailsEditorFactory details_editor_factory = new Editor.DetailsEditorFactory ();

  [GtkChild]
  private Grid container_grid;

  // Template subwidgets
  [GtkChild]
  private ScrolledWindow main_sw;
  [GtkChild]
  private MenuButton add_detail_button;
  [GtkChild]
  public Button linked_button;
  [GtkChild]
  public Button remove_button;

  // Actions
  private SimpleActionGroup edit_contact_actions;
  private const GLib.ActionEntry[] action_entries = {
    { "add-email-addresses", on_add_detail },
    { "add-phone-numbers", on_add_detail },
    { "add-urls", on_add_detail },
    { "add-nickname", on_add_detail },
    { "add-birthday", on_add_detail },
    { "add-postal-addresses", on_add_detail },
    { "add-notes", on_add_detail },
  };

  public bool has_birthday_row {
    get; private set; default = false;
  }

  public bool has_nickname_row {
    get; private set; default = false;
  }

  public bool has_notes_row {
    get; private set; default = false;
  }

  public ContactEditor (Contact? contact, Store store) {
    this.contact = contact;
    this.store = store;

    create_actions ();
    init_layout ();

    if (contact != null) {
      // Load the contact's personas and their editable properties
      bool first_persona = true;
      foreach (var persona in contact.get_personas_for_display ()) {
        add_widgets_for_persona (persona, first_persona);
        first_persona = false;
      }

      // Show "Remove" and "Link" buttons
      this.remove_button.show ();
      this.remove_button.sensitive = this.contact.can_remove_personas ();
      this.linked_button.show ();
      this.linked_button.sensitive = this.contact.individual.personas.size > 1;
    } else {
      // Init the editor with the default properties
      add_widgets_for_persona (null);
    }
  }

  private void create_actions () {
    this.edit_contact_actions = new SimpleActionGroup ();
    this.edit_contact_actions.add_action_entries (action_entries, this);
  }

  // Initializes the basic layout
  private void init_layout () {
    this.container_grid.set_focus_vadjustment (this.main_sw.get_vadjustment ());

    this.main_sw.get_child ().get_style_context ().add_class ("contacts-main-view");
    this.main_sw.get_child ().get_style_context ().add_class ("view");

    this.add_detail_button.get_popover ().insert_action_group ("edit", this.edit_contact_actions);

    // enable/disable actions
    var birthday_action = this.edit_contact_actions.lookup_action ("add.birthday") as SimpleAction;
    // XXX de volgende dingen werken niet meer want die properties zijn weg :-)
    /* bind_property ("has-birthday-row", birthday_action, "enabled", */
    /*                BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN); */

    var nickname_action = this.edit_contact_actions.lookup_action ("add.nickname") as SimpleAction;
    /* bind_property ("has-nickname-row", nickname_action, "enabled", */
    /*                BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN); */

    var notes_action = this.edit_contact_actions.lookup_action ("add.notes") as SimpleAction;
    /* bind_property ("has-notes-row", notes_action, "enabled", */
    /*                BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN); */
  }

  // Adds the widgets for the details in a persona
  private void add_widgets_for_persona (Persona? persona, bool first_persona = true) {
    var form = Form ();
    form.persona = persona;
    form.editors = new ArrayList<Editor.DetailsEditor> ();
    this.forms.add (form);

    if (first_persona) {
      create_avatar_frame (form);
      create_name_entry (form);
      this.next_row += 3;
    } else {
      // Don't show the name on the default persona
      var store_name = new Label (Contact.format_persona_store_name_for_contact (persona));
      store_name.halign = Align.START;
      store_name.xalign = 0.0f; // XXX don't use xalign
      store_name.margin_start = 6;
      this.container_grid.attach (store_name, 0, this.next_row, 2);
      this.next_row++;
    }

    string[] writeable_props;
    if (persona != null)
      writeable_props = Contact.sort_persona_properties (persona.writeable_properties);
    else
      writeable_props = DEFAULT_PROPS_NEW_CONTACT;

    foreach (var prop in writeable_props)
      add_property (form, prop, (persona == null));
  }

  private void add_property (Form form, string prop_name, bool allow_empty = false) {
    var editor = this.details_editor_factory.create_details_editor (form.persona, prop_name, allow_empty);
    if (editor != null) {
      form.editors.add (editor);
      var rows_added = editor.attach_to_grid (this.container_grid, this.next_row);
      this.next_row += rows_added;
    }
  }

  // Creates the contact's current avatar, the big frame on top of the Editor
  private void create_avatar_frame (Form form) {
    var avatar_editor = new Editor.AvatarEditor (this.contact, form.persona as AvatarDetails);
    avatar_editor.attach_to_grid (this.container_grid, 0);
    form.editors.add (avatar_editor);
  }

  // Creates the big name entry on the top
  private void create_name_entry (Form form) {
    var full_name_editor = new Editor.FullNameEditor (this.contact, form.persona as NameDetails);
    full_name_editor.attach_to_grid (this.container_grid, 0);
    form.editors.add (full_name_editor);
  }

  public async Contact save_changes () throws Error {
    if (this.contact == null) {
      var details = new HashTable<string, Value?> (str_hash, str_equal);
      var contacts_store = this.store;

      //XXX check if name is filled in
      var form = this.forms[0];
      foreach (var details_editor in form.editors)
        if (details_editor.dirty)
          details[details_editor.persona_property] = details_editor.create_value ();

      if (details.size () != 0)
        throw new SaveError.EMPTY_DATA (_("You need to enter some data"));

      if (contacts_store.aggregator.primary_store == null)
        throw new SaveError.NO_PRIMARY_ADDRESSBOOK (_("No primary addressbook configured"));

      // Create the contact
      var primary_store = contacts_store.aggregator.primary_store;
      var persona = yield Contact.create_primary_persona_for_details (primary_store, details);

      return contacts_store.find_contact_with_persona (persona);
    }

    //XXX check for empty values
    warning("SAVING WITH %d forms", this.forms.size);
    foreach (var form in this.forms) {
      warning("FORM WITH %d editors", form.editors.size);//XXX
      foreach (var details_editor in form.editors) {
        debug("FORM EDITOR %s (dirty: %s)", details_editor.get_type().name(), (details_editor.dirty).to_string());//XXX
        if (details_editor.dirty)
          yield details_editor.save_to_persona (form.persona);
      }
    }
    return this.contact;
  }

  private void on_add_detail (SimpleAction action, Variant? parameter) {
    var tok = action.name.split ("-", 2);

    // The name of the property we're adding
    var property = tok[1];

    // Get the form for the primary persona (if any)
    Form? form = null;
    if (contact != null) {
        var primary_persona = contact.find_primary_persona ();
        foreach (var f in this.forms) {
            if (f.persona == primary_persona) {
                form = f;
                break;
            }
        }
    }
    form = form ?? this.forms[0]; // Take the first form available

    // Add the property to the form
    add_property (form, property, true);
  }
}
