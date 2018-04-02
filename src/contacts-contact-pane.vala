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

const int PROFILE_SIZE = 128;

/**
 * The ContactPage is the right pane. It consists of 3 possible pages:
 * a page if nothing is selected, a ContactSheet to view contact information,
 * and a ContactEditor to edit contact information.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-contact-pane.ui")]
public class Contacts.ContactPane : Stack {

  private Window parent_window;

  private Store store;

  public Contact? contact = null;

  [GtkChild]
  private Grid none_selected_page;

  [GtkChild]
  private ScrolledWindow contact_sheet_page;
  [GtkChild]
  private Container contact_sheet_container;
  private ContactSheet? sheet = null;

  [GtkChild]
  private Box contact_editor_page;
  private ContactEditor editor;

  private SimpleActionGroup edit_contact_actions = new SimpleActionGroup ();
  private const GLib.ActionEntry[] action_entries = {
    { "add.email-addresses.home", on_add_detail },
    { "add.email-addresses.work", on_add_detail },
    { "add.phone-numbers.cell", on_add_detail },
    { "add.phone-numbers.home", on_add_detail },
    { "add.phone-numbers.work", on_add_detail },
    { "add.urls", on_add_detail },
    { "add.nickname", on_add_detail },
    { "add.birthday", on_add_detail },
    { "add.postal-addresses.home", on_add_detail },
    { "add.postal-addresses.work", on_add_detail },
    { "add.notes", on_add_detail },
  };

  public bool on_edit_mode = false;
  private LinkSuggestionGrid? suggestion_grid = null;

  /* Signals */
  public signal void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation);
  public signal void will_delete (Contact contact);
  /**
   * Passes the changed display name to all listeners after edit mode has been completed.
   */
  public signal void display_name_changed (string new_display_name);


  public void add_suggestion (Contact c) {
    var parent_overlay = this.get_parent () as Overlay;

    remove_suggestion_grid ();
    this.suggestion_grid = new LinkSuggestionGrid (c);
    parent_overlay.add_overlay (this.suggestion_grid);

    this.suggestion_grid.suggestion_accepted.connect ( () => {
        var linked_contact = c.individual.display_name;
        link_contacts.begin (contact, c, this.store, (obj, result) => {
            var operation = link_contacts.end (result);
            this.contacts_linked (null, linked_contact, operation);
          });
        remove_suggestion_grid ();
      });

    this.suggestion_grid.suggestion_rejected.connect ( () => {
        /* TODO: Add undo */
        store.add_no_suggest_link (contact, c);
        remove_suggestion_grid ();
      });
  }

  public void show_contact (Contact? contact) {
    if (this.contact == contact)
      return;

    this.contact = contact;

    if (this.contact != null) {
      show_contact_sheet ();
    } else {
      remove_contact_sheet ();
      set_visible_child (this.none_selected_page);
    }
  }

  public ContactPane (Window parent_window, Store contacts_store) {
    this.parent_window = parent_window;
    this.store = contacts_store;

    this.edit_contact_actions.add_action_entries (action_entries, this);

    // Contact editor
    this.editor = new ContactEditor (this.store, this.edit_contact_actions);
    this.editor.linked_button.clicked.connect (linked_accounts);
    this.editor.remove_button.clicked.connect (delete_contact);
    this.contact_editor_page.add (this.editor);

    /* enable/disable actions*/
    var birthday_action = this.edit_contact_actions.lookup_action ("add.birthday") as SimpleAction;
    this.editor.bind_property ("has-birthday-row",
                               birthday_action, "enabled",
                               BindingFlags.SYNC_CREATE |
                               BindingFlags.INVERT_BOOLEAN);

    var nickname_action = this.edit_contact_actions.lookup_action ("add.nickname") as SimpleAction;
    this.editor.bind_property ("has-nickname-row",
                               nickname_action, "enabled",
                               BindingFlags.DEFAULT |
                               BindingFlags.SYNC_CREATE |
                               BindingFlags.INVERT_BOOLEAN);

    var notes_action = this.edit_contact_actions.lookup_action ("add.notes") as SimpleAction;
    this.editor.bind_property ("has-notes-row",
                               notes_action, "enabled",
                               BindingFlags.DEFAULT |
                               BindingFlags.SYNC_CREATE |
                               BindingFlags.INVERT_BOOLEAN);
  }

  private void show_contact_sheet () {
    assert (this.contact != null);

    remove_contact_sheet();
    this.sheet = new ContactSheet (this.contact, this.store);
    this.contact_sheet_container.add (this.sheet);
    this.sheet.set_focus_vadjustment (this.contact_sheet_page.get_vadjustment ());
    set_visible_child (this.contact_sheet_page);
  }

  private void remove_contact_sheet () {
    if (this.sheet == null)
      return;

    // Remove the suggestion grid that goes along with it.
    remove_suggestion_grid ();

    this.contact_sheet_container.remove (this.sheet);
    this.sheet.destroy();
    this.sheet = null;
  }

  void on_add_detail (GLib.SimpleAction action, GLib.Variant? parameter) {
    var tok = action.name.split (".");

    if (tok[0] == "add") {
      editor.add_new_row_for_property (contact.find_primary_persona (),
				       tok[1],
				       tok.length > 2 ? tok[2].up () : null);
    }
  }

  private void linked_accounts () {
    var dialog = new LinkedPersonasDialog (this.parent_window, this.store, contact);
    if (dialog.run () == ResponseType.CLOSE && dialog.any_unlinked) {
      /* update edited contact if any_unlinked */
      set_edit_mode (false);
      set_edit_mode (true);
    }
    dialog.destroy ();
  }

  void delete_contact () {
    if (contact != null) {
      contact.hidden = true;
      this.will_delete (contact);
    }
  }

  public void set_edit_mode (bool on_edit, bool drop_changes = false) {
    if (on_edit == on_edit_mode)
      return;

    if (on_edit) {
      if (contact == null) {
	return;
      }

      on_edit_mode = true;

      remove_contact_sheet ();

      editor.clear ();
      editor.edit (contact);
      editor.show_all ();
      set_visible_child (this.contact_editor_page);
    } else {
      on_edit_mode = false;
      /* saving changes */
      if (!drop_changes) {
	foreach (var prop in editor.properties_changed ().entries) {
	  Contact.set_persona_property.begin (prop.value.persona, prop.key, prop.value.value,
					      (obj, result) => {
						try {
						  Contact.set_persona_property.end (result);
						} catch (Error e2) {
						  show_message (e2.message);
						}
					      });
	}

	if (editor.name_changed ()) {
	  var v = editor.get_full_name_value ();
	  Contact.set_individual_property.begin (contact,
						 "full-name", v,
						 (obj, result) => {
						   try {
						     Contact.set_individual_property.end (result);
						     display_name_changed (v.get_string ());
						   } catch (Error e) {
						     show_message (e.message);
						     /* FIXME: add this back */
						     /* l.set_markup (Markup.printf_escaped ("<span font='16'>%s</span>", contact.display_name)); */
						   }
						 });
	}
	if (editor.avatar_changed ()) {
	  var v = editor.get_avatar_value ();
	  Contact.set_individual_property.begin (contact,
						 "avatar", v,
						 (obj, result) => {
						   try {
						     Contact.set_individual_property.end (result);
						   } catch (GLib.Error e) {
						     show_message (e.message);
						   }
						 });
	}
      }

      editor.clear ();

      if (contact != null) {
        show_contact_sheet ();
      } else {
        set_visible_child (this.none_selected_page);
      }
    }
  }

  public void new_contact () {
    on_edit_mode = true;

    remove_contact_sheet ();

    editor.set_new_contact ();

    set_visible_child (this.contact_editor_page);
  }

  // Creates a new contact from the details in the ContactEditor
  public async void create_contact () {
    var details = new HashTable<string, Value?> (str_hash, str_equal);

    // Collect the details from the editor
    if (editor.name_changed ())
      details["full-name"] = this.editor.get_full_name_value ();

    if (editor.avatar_changed ())
      details["avatar"] = this.editor.get_avatar_value ();

    foreach (var prop in this.editor.properties_changed ().entries)
      details[prop.key] = prop.value.value;

    // Leave edit mode
    set_edit_mode (false, true);

    if (details.size () == 0) {
      show_message_dialog (_("You need to enter some data"));
      return;
    }

    if (this.store.aggregator.primary_store == null) {
      show_message_dialog (_("No primary addressbook configured"));
      return;
    }

    // Create the contact
    var primary_store = this.store.aggregator.primary_store;
    Persona? persona = null;
    try {
      persona = yield Contact.create_primary_persona_for_details (primary_store, details);
    } catch (Error e) {
      show_message_dialog (_("Unable to create new contacts: %s").printf (e.message));
      return;
    }

    // Now show it to the user
    var contact = this.store.find_contact_with_persona (persona);
    if (contact != null)
      this.parent_window.set_shown_contact (contact);
    else
      show_message_dialog (_("Unable to find newly created contact"));
  }

  private void show_message_dialog (string message) {
    var dialog =
        new MessageDialog (this.parent_window,
                           DialogFlags.DESTROY_WITH_PARENT | DialogFlags.MODAL,
                           MessageType.ERROR,
                           ButtonsType.OK,
                           message);
    dialog.run ();
    dialog.destroy ();
  }

  private void show_message (string message) {
    var notification = new InAppNotification (message);
    notification.show ();
    this.parent_window.add_notification (notification);
  }

  private void remove_suggestion_grid () {
    if (this.suggestion_grid == null)
      return;

    this.suggestion_grid.destroy ();
    this.suggestion_grid = null;
  }
}
