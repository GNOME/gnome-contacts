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

  public Contact? contact;

  [GtkChild]
  private Grid none_selected_page;

  [GtkChild]
  private ScrolledWindow contact_sheet_page;
  private ContactSheet sheet;

  [GtkChild]
  private Box contact_editor_page;
  private Editor.ContactEditor? editor;

  public bool on_edit_mode;
  private LinkSuggestionGrid suggestion_grid;


  public signal void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation);
  public signal void will_delete (Contact contact);


  public ContactPane (Window parent_window, Store contacts_store) {
    this.parent_window = parent_window;
    this.store = contacts_store;
    this.store.quiescent.connect (update_sheet);

    create_contact_sheet ();

    this.suggestion_grid = null;

    /* edit mode widgetry, third page */
    this.on_edit_mode = false;
  }

  public void update_sheet () {
    if (on_edit_mode) {
      /* this was triggered by some signal, do nothing */
      return;
    }

    sheet.clear ();

    if (contact == null)
      return;

    sheet.update (contact);
    set_visible_child (this.contact_sheet_page);

    var matches = contact.store.aggregator.get_potential_matches (contact.individual, MatchResult.HIGH);
    foreach (var ind in matches.keys) {
      var c = Contact.from_individual (ind);
      if (c != null && contact.suggest_link_to (c)) {
        add_suggestion (c);
      }
    }
  }

  public void add_suggestion (Contact c) {
    var parent_overlay = this.get_parent () as Overlay;

    if (suggestion_grid != null) {
      suggestion_grid.destroy ();
      suggestion_grid = null;
    }

    this.suggestion_grid = new LinkSuggestionGrid (c);
    parent_overlay.add_overlay (this.suggestion_grid);

    this.suggestion_grid.suggestion_accepted.connect ( () => {
        var linked_contact = c.individual.display_name;
        link_contacts.begin (contact, c, this.store, (obj, result) => {
            var operation = link_contacts.end (result);
            this.contacts_linked (null, linked_contact, operation);
          });
        this.suggestion_grid.destroy ();
      });

    this.suggestion_grid.suggestion_rejected.connect ( () => {
        store.add_no_suggest_link (contact, c);
        /* TODO: Add undo */
        this.suggestion_grid.destroy ();
      });
  }

  public void show_contact (Contact? new_contact, bool show_matches = true) {
    if (contact == new_contact)
      return;

    if (suggestion_grid != null) {
      suggestion_grid.destroy ();
      suggestion_grid = null;
    }

    if (contact != null) {
      contact.personas_changed.disconnect (update_sheet);
      contact.changed.disconnect (update_sheet);
    }

    contact = new_contact;

    update_sheet ();

    if (contact != null) {
      contact.personas_changed.connect (update_sheet);
      contact.changed.connect (update_sheet);
    }

    if (contact == null)
      set_visible_child (this.none_selected_page);
  }

  private void create_contact_sheet () {
    this.sheet = new ContactSheet ();
    this.sheet.hexpand = true;
    this.sheet.vexpand = true;
    this.sheet.margin = 36;
    this.sheet.set_margin_bottom (24);

    var hcenter = new Center ();
    hcenter.max_width = 600;
    hcenter.show ();
    hcenter.add (this.sheet);

    this.contact_sheet_page.add (hcenter);
    this.sheet.set_focus_vadjustment (this.contact_sheet_page.get_vadjustment ());

    this.contact_sheet_page.get_child ().get_style_context ().add_class ("contacts-main-view");
    this.contact_sheet_page.get_child ().get_style_context ().add_class ("view");
  }

  private void linked_accounts () {
    var dialog = new LinkedPersonasDialog (this.parent_window, contact);
    if (dialog.run () == ResponseType.CLOSE && dialog.any_unlinked) {
      /* update edited contact if any_unlinked */
      set_edit_mode (false);
      set_edit_mode (true);
    }
    dialog.destroy ();
  }

  // Start editing a contact: initialize and show the contact editor
  private void load_contact_editor (Contact? contact) {
    this.editor = new Editor.ContactEditor (contact, this.store);
    this.editor.linked_button.clicked.connect (linked_accounts);
    this.editor.remove_button.clicked.connect (delete_contact);
    this.contact_editor_page.add (this.editor);
    set_visible_child (this.contact_editor_page);
  }

  private void remove_contact_editor () {
    SignalHandler.disconnect_by_func (this.editor.linked_button, (void*) linked_accounts, this);
    SignalHandler.disconnect_by_func (this.editor.remove_button, (void*) delete_contact, this);
    this.contact_editor_page.remove (this.editor);
    this.editor = null;
  }

  void delete_contact () {
    if (contact != null) {
      contact.hide ();

      this.will_delete (contact);
    }
  }

  public void set_edit_mode (bool on_edit, bool drop_changes = false) {
    if (on_edit == on_edit_mode)
      return;

    if (on_edit) {
      if (this.contact == null)
        return;

      this.on_edit_mode = true;

      this.sheet.clear ();

      if (suggestion_grid != null) {
        this.suggestion_grid.destroy ();
        this.suggestion_grid = null;
      }

      load_contact_editor (this.contact);
    } else {
      this.on_edit_mode = false;
      /* saving changes */
      if (!drop_changes) {
        this.editor.save_changes.begin ( (obj, res) => {
            try {
              this.editor.save_changes.end (res);
            } catch (Error e) {
              show_message (e.message);
              update_sheet ();
            }
          });
      }

      remove_contact_editor ();

      if (this.contact != null) {
        this.sheet.clear ();
        this.sheet.update (contact);
        set_visible_child (this.contact_sheet_page);
      } else {
        set_visible_child (this.none_selected_page);
      }
    }
  }

  public void new_contact () {
    on_edit_mode = true;

    sheet.clear ();

    if (suggestion_grid != null) {
      suggestion_grid.destroy ();
      suggestion_grid = null;
    }

    this.contact = null;
    load_contact_editor (this.contact);
  }

  // Creates a new contact from the details in the ContactEditor
  public async void create_contact () {
    // Leave edit mode
    set_edit_mode (false, true);

    try {
      var contact = yield this.editor.save_changes ();
      // Now show it to the user
      if (contact != null)
        this.parent_window.set_shown_contact (contact);
      else
        show_message_dialog (_("Unable to find newly created contact"));
    } catch (Error e) {
      show_message_dialog (_("Unable to create new contacts: %s").printf (e.message));
    }
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
}
