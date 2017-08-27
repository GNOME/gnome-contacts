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

const int PROFILE_SIZE = 96;

/**
 * The ContactPage is the right pane. It consists of 3 possible pages:
 * a page if nothing is selected, a ContactSheet to view contact information,
 * and a ContactEditor to edit contact information.
 */
[GtkTemplate (ui = "/org/gnome/contacts/ui/contacts-contact-pane.ui")]
public class Contacts.ContactPane : Stack {

  private Store _store;
  public Store store {
    get {
      return _store;
    }
    set {
      _store = value;

      // Refresh the view when the store is quiescent as we may have missed
      // some potential matches while the store was still preparing.
      if (value != null) {
	_store.quiescent.connect (update_sheet);
      }
    }
    default = null;
  }

  public Contact? contact;

  [GtkChild]
  private Grid none_selected_page;

  [GtkChild]
  private ScrolledWindow contact_sheet_page;
  private ContactSheet sheet;

  [GtkChild]
  private Box contact_editor_page;
  private ContactEditor editor;

  private SimpleActionGroup edit_contact_actions;
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

  public bool on_edit_mode;
  public Grid suggestion_grid;

  /* Signals */
  public signal void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation);
  public signal void will_delete (Contact contact);

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

    suggestion_grid = new Grid ();
    suggestion_grid.set_valign (Align.END);
    parent_overlay.add_overlay (suggestion_grid);

    suggestion_grid.get_style_context ().add_class ("contacts-suggestion");
    suggestion_grid.set_redraw_on_allocate (true);
    suggestion_grid.draw.connect ( (cr) => {
	Allocation allocation;
	suggestion_grid.get_allocation (out allocation);

	var context = suggestion_grid.get_style_context ();
	context.render_background (cr,
				   0, 0,
				   allocation.width, allocation.height);
	return false;
      });

    var image_frame = new ContactFrame (Contact.SMALL_AVATAR_SIZE);
    image_frame.set_hexpand (false);
    image_frame.margin = 24;
    image_frame.margin_end = 12;
    c.keep_widget_uptodate (image_frame,  (w) => {
	(w as ContactFrame).set_image (c.individual, c);
      });

    suggestion_grid.attach (image_frame, 0, 0, 1, 2);

    var label = new Label ("");
    if (contact.is_main)
      label.set_markup (Markup.printf_escaped (_("Does %s from %s belong here?"), c.display_name, c.format_persona_stores ()));
    else
      label.set_markup (Markup.printf_escaped (_("Do these details belong to %s?"), c.display_name));
    label.set_valign (Align.START);
    label.set_halign (Align.START);
    label.set_line_wrap (true);
    label.width_chars = 20;
    label.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    label.set_hexpand (true);
    label.margin_top = 24;
    label.margin_bottom = 24;
    suggestion_grid.attach (label, 1, 0, 1, 2);

    var bbox = new ButtonBox (Orientation.HORIZONTAL);
    var yes = new Button.with_label (_("Yes"));
    var no = new Button.with_label (_("No"));

    yes.clicked.connect ( () => {
      var linked_contact = c.display_name;
      link_contacts.begin (contact, c, (obj, result) => {
	var operation = link_contacts.end (result);
	this.contacts_linked (null, linked_contact, operation);
      });
      suggestion_grid.destroy ();
    });

    no.clicked.connect ( () => {
	store.add_no_suggest_link (contact, c);
	/* TODO: Add undo */
	suggestion_grid.destroy ();
      });

    bbox.add (yes);
    bbox.add (no);
    bbox.set_spacing (8);
    bbox.set_halign (Align.END);
    bbox.set_hexpand (true);
    bbox.margin = 24;
    bbox.margin_start = 12;
    suggestion_grid.attach (bbox, 2, 0, 1, 2);
    suggestion_grid.show_all ();
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

  construct {
    this.edit_contact_actions = new SimpleActionGroup ();
    this.edit_contact_actions.add_action_entries (action_entries, this);

    // contact editor page
    sheet = new ContactSheet ();
    sheet.hexpand = true;
    sheet.vexpand = true;
    sheet.margin = 36;
    sheet.set_margin_bottom (24);

    var hcenter = new Center ();
    hcenter.max_width = 600;
    hcenter.xalign = 0.0;
    hcenter.show ();
    hcenter.add (sheet);

    this.contact_sheet_page.add (hcenter);
    sheet.set_focus_vadjustment (this.contact_sheet_page.get_vadjustment ());

    this.contact_sheet_page.get_child ().get_style_context ().add_class ("contacts-main-view");
    this.contact_sheet_page.get_child ().get_style_context ().add_class ("view");

    this.suggestion_grid = null;

    /* edit mode widgetry, third page */
    this.on_edit_mode = false;
    this.editor = new ContactEditor (this.edit_contact_actions);
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

  void on_add_detail (GLib.SimpleAction action, GLib.Variant? parameter) {
    var tok = action.name.split (".");

    if (tok[0] == "add") {
      editor.add_new_row_for_property (contact.find_primary_persona (),
				       tok[1],
				       tok.length > 2 ? tok[2].up () : null);
    }
  }

  private void linked_accounts () {
    var dialog = new LinkedAccountsDialog ((Window) get_toplevel (), contact);
    var result = dialog.run ();
    if (result == ResponseType.CLOSE &&
	dialog.any_unlinked) {
      /* update edited contact if any_unlinked */
      set_edit_mode (false);
      set_edit_mode (true);
    }
    dialog.destroy ();
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
      if (contact == null) {
	return;
      }

      on_edit_mode = true;

      sheet.clear ();

      if (suggestion_grid != null) {
	suggestion_grid.destroy ();
	suggestion_grid = null;
      }

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
						  App.app.show_message (e2.message);
						  update_sheet ();
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
						   } catch (Error e) {
						     App.app.show_message (e.message);
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
						     App.app.show_message (e.message);
						   }
						 });
	}
      }

      editor.clear ();

      if (contact != null) {
        sheet.clear ();
        sheet.update (contact);
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
      App.app.show_contact (contact);
    else
      show_message_dialog (_("Unable to find newly created contact"));
  }

  private void show_message_dialog (string message) {
    var dialog =
        new MessageDialog (this.get_toplevel () as Window,
                           DialogFlags.DESTROY_WITH_PARENT | DialogFlags.MODAL,
                           MessageType.ERROR,
                           ButtonsType.OK,
                           message);
    dialog.run ();
    dialog.destroy ();
  }
}
