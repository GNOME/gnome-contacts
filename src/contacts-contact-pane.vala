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

const int PROFILE_SIZE = 96;

namespace Contacts {
  public static void change_avatar (Contact contact, ContactFrame image_frame) {
    var dialog = new AvatarDialog (contact);
    dialog.show ();
    dialog.set_avatar.connect ( (icon) =>  {
	Value v = Value (icon.get_type ());
	v.set_object (icon);
	Contact.set_individual_property.begin (contact,
					       "avatar", v,
					       (obj, result) => {
						 try {
						   Contact.set_individual_property.end (result);
						 } catch (GLib.Error e) {
						   App.app.show_message (e.message);
						   image_frame.set_image (contact.individual, contact);
					       }
					       });
      });
  }
}

public class Contacts.ContactPane : Notebook {
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

  /* 3 pages, first */
  private Grid none_selected_view;

  /* second page */
  private ContactSheet sheet;

  /* third page */
  private ContactEditor editor;

  private SimpleActionGroup edit_contact_actions;
  private const GLib.ActionEntry[] action_entries = {
    { "add.email-addresses.personal", on_add_detail },
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
    set_current_page (1);

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
      show_none_selected_view ();
  }

  construct {
    this.show_border = false;

    this.edit_contact_actions = new SimpleActionGroup ();
    this.edit_contact_actions.add_action_entries (action_entries, this);

    /* starts with none_selected_view 'til someone select something */
    show_none_selected_view ();

    var main_sw = new ScrolledWindow (null, null);

    main_sw.set_shadow_type (ShadowType.NONE);
    main_sw.set_hexpand (true);
    main_sw.set_vexpand (true);
    main_sw.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

    var hcenter = new Center ();
    hcenter.max_width = 600;
    hcenter.xalign = 0.0;

    sheet = new ContactSheet ();
    hcenter.add (sheet);

    sheet.set_hexpand (true);
    sheet.set_vexpand (true);
    sheet.margin = 36;
    sheet.set_margin_bottom (24);

    main_sw.add (hcenter);
    sheet.set_focus_vadjustment (main_sw.get_vadjustment ());

    main_sw.get_child ().get_style_context ().add_class ("contacts-main-view");
    main_sw.get_child ().get_style_context ().add_class ("view");

    main_sw.show_all ();
    insert_page (main_sw, null, 1);

    suggestion_grid = null;

    /* edit mode widgetry, third page */
    on_edit_mode = false;
    editor = new ContactEditor (this.edit_contact_actions);
    editor.linked_button.clicked.connect (linked_accounts);
    editor.remove_button.clicked.connect (delete_contact);
    insert_page (editor, null, 2);

    /* enable/disable actions*/
    var birthday_action = this.edit_contact_actions.lookup_action ("add.birthday") as SimpleAction;
    editor.bind_property ("has-birthday-row",
			  birthday_action, "enabled",
			  BindingFlags.SYNC_CREATE |
			  BindingFlags.INVERT_BOOLEAN);

    var nickname_action = this.edit_contact_actions.lookup_action ("add.nickname") as SimpleAction;
    editor.bind_property ("has-nickname-row",
			  nickname_action, "enabled",
			  BindingFlags.DEFAULT |
			  BindingFlags.SYNC_CREATE |
			  BindingFlags.INVERT_BOOLEAN);

    var notes_action = this.edit_contact_actions.lookup_action ("add.notes") as SimpleAction;
    editor.bind_property ("has-notes-row",
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

  void linked_accounts () {
    var dialog = new LinkedAccountsDialog (contact);
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

  void show_none_selected_view () {
    if (none_selected_view == null) {
      none_selected_view = new Grid ();
      none_selected_view.set_size_request (500, -1);
      none_selected_view.set_orientation (Orientation.VERTICAL);
      none_selected_view.set_vexpand (true);
      none_selected_view.set_hexpand (true);

      var icon_theme = IconTheme.get_default ();
      var pix = icon_theme.load_icon ("avatar-default-symbolic", 144, 0);

      var image = new Image.from_pixbuf (pix);
      image.get_style_context ().add_class ("contacts-watermark");
      image.set_vexpand (true);
      image.set_valign (Align.END);
      none_selected_view.add (image);

      var label = new Gtk.Label ("");
      label.set_markup ("<span font=\"12\">%s</span>".printf (_("Select a contact")));
      label.get_style_context ().add_class ("contacts-watermark");
      label.set_vexpand (true);
      label.set_hexpand (true);
      label.set_valign (Align.START);
      label.margin_bottom = 70;
      none_selected_view.add (label);

      none_selected_view.show_all ();
      insert_page (none_selected_view, null, 0);
    }

    set_current_page (0);
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
      editor.update (contact);
      editor.show_all ();
      set_current_page (2);
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
      }

      editor.clear ();

      sheet.clear ();
      sheet.update (contact);
      set_current_page (1);
    }
  }
}
