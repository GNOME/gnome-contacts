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

const int PROFILE_SIZE = 128;

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

public class Contacts.ContactPane : Grid {
  private Store contacts_store;
  public Contact? contact;

  private ScrolledWindow main_sw;
  private Grid top_grid;
  private ContactSheet sheet;

  public bool on_edit_mode;
  private Gd.MainToolbar edit_toolbar;
  private Revealer edit_revealer;
  private ContactEditor editor;

  /* single value details */
  private Gtk.MenuItem nickname_item;
  private Gtk.MenuItem birthday_item;
  private Gtk.MenuItem notes_item;

  private Grid no_selection_grid;

  public Grid suggestion_grid;

  /* Signals */
  public signal void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation);
  public signal void will_delete (Contact contact);

  public void update_sheet (bool show_matches = true) {
    if (on_edit_mode) {
      /* this was triggered by some signal, do nothing */
      return;
    }

    sheet.clear ();

    if (contact == null)
      return;

    sheet.update (contact);

    if (show_matches) {
      var matches = contact.store.aggregator.get_potential_matches (contact.individual, MatchResult.HIGH);
      foreach (var ind in matches.keys) {
	var c = Contact.from_individual (ind);
	if (c != null && contact.suggest_link_to (c)) {
	  add_suggestion (c);
	}
      }
    }
  }

  public void add_suggestion (Contact c) {
    var parent_overlay = this.get_parent () as Overlay;

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
    image_frame.margin_right = 12;
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
	contacts_store.add_no_suggest_link (contact, c);
	/* TODO: Add undo */
	suggestion_grid.destroy ();
      });

    bbox.add (yes);
    bbox.add (no);
    bbox.set_spacing (8);
    bbox.set_halign (Align.END);
    bbox.set_hexpand (true);
    bbox.margin = 24;
    bbox.margin_left = 12;
    suggestion_grid.attach (bbox, 2, 0, 1, 2);
    suggestion_grid.show_all ();
  }

  public void show_contact (Contact? new_contact, bool edit = false, bool show_matches = true) {
    if (contact == new_contact)
      return;

    if (contact != null) {
      contact.personas_changed.disconnect (personas_changed_cb);
      contact.changed.disconnect (contact_changed_cb);
    }
    if (new_contact != null) {
      no_selection_grid.destroy ();
    }

    contact = new_contact;

    update_sheet ();

    if (suggestion_grid != null)
      suggestion_grid.destroy ();

    bool can_remove = false;

    if (contact != null) {
      contact.personas_changed.connect (personas_changed_cb);
      contact.changed.connect (contact_changed_cb);

      can_remove = contact.can_remove_personas ();
    }

    if (contact == null)
      show_no_selection_grid ();
  }

  private void personas_changed_cb (Contact contact) {
    update_sheet ();
  }

  private void contact_changed_cb (Contact contact) {
    update_sheet ();
  }

  struct ImValue {
    string protocol;
    string id;
    string name;
  }

  public void start_chat () {
    var ims = contact.individual.im_addresses;
    var im_keys = ims.get_keys ();
    var online_personas = new ArrayList<ImValue?>();
    if (contact != null) {
      foreach (var protocol in im_keys) {
	foreach (var id in ims[protocol]) {
	  var im_persona = contact.find_im_persona (protocol, id.value);
	  if (im_persona != null) {
	    var type = im_persona.presence_type;
	    if (type != PresenceType.UNSET &&
		type != PresenceType.ERROR &&
		type != PresenceType.OFFLINE &&
		type != PresenceType.UNKNOWN) {
	      ImValue? value = { protocol, id.value, Contact.format_im_name (im_persona, protocol, id.value) };
	      online_personas.add (value);
	    }
	  }
	}
      }
    }

    if (online_personas.is_empty)
      return;

    if (online_personas.size == 1) {
      foreach (var value in online_personas) {
	Utils.start_chat (contact, value.protocol, value.id);
      }
    }
  }

  public ContactPane (Store contacts_store) {
    this.set_orientation (Orientation.VERTICAL);

    this.contacts_store = contacts_store;

    main_sw = new ScrolledWindow (null, null);
    main_sw.get_style_context ().add_class ("contacts-content");
    this.add (main_sw);

    main_sw.set_shadow_type (ShadowType.IN);
    main_sw.set_hexpand (true);
    main_sw.set_vexpand (true);
    main_sw.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

    top_grid = new Grid ();
    top_grid.set_orientation (Orientation.VERTICAL);
    top_grid.margin = 36;
    top_grid.set_margin_bottom (24);
    top_grid.set_row_spacing (20);
    main_sw.add_with_viewport (top_grid);
    top_grid.set_focus_vadjustment (main_sw.get_vadjustment ());

    main_sw.get_child ().get_style_context ().add_class ("contacts-main-view");
    main_sw.get_child ().get_style_context ().add_class ("view");

    sheet = new ContactSheet ();
    top_grid.add (sheet);
    top_grid.show_all ();

    contacts_store.quiescent.connect (() => {
      // Refresh the view when the store is quiescent as we may have missed
      // some potential matches while the store was still preparing.
      update_sheet ();
    });

    suggestion_grid = null;

    /* starts with no_selection_grid 'til someone select something */
    show_no_selection_grid ();

    /* edit mode widgetry */
    editor = new ContactEditor ();

    on_edit_mode = false;
    edit_toolbar = new Gd.MainToolbar ();
    edit_toolbar.get_style_context ().add_class (STYLE_CLASS_MENUBAR);
    edit_toolbar.get_style_context ().add_class ("contacts-edit-toolbar");
    edit_toolbar.set_vexpand (false);

    var add_detail_button = new Gtk.MenuButton ();
    var box = new Grid ();
    box.set_column_spacing (4);
    box.add (new Label (_("New Detail ...")));
    box.add (new Arrow (ArrowType.DOWN, ShadowType.OUT));
    add_detail_button.add (box);
    var details_menu = new Gtk.Menu ();
    details_menu.set_halign (Align.END);
    var item = new Gtk.MenuItem.with_label (_("Email"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "email-addresses");
      });
    item = new Gtk.MenuItem.with_label (_("Phone"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "phone-numbers");
      });
    item = new Gtk.MenuItem.with_label (_("Link"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "urls");
      });
    nickname_item = new Gtk.MenuItem.with_label (_("Nickname"));
    details_menu.append (nickname_item);
    nickname_item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "nickname");
      });
    birthday_item = new Gtk.MenuItem.with_label (_("Birthday"));
    details_menu.append (birthday_item);
    birthday_item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "birthday");
      });
    item = new Gtk.MenuItem.with_label (_("Address"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "postal-address");
      });
    notes_item = new Gtk.MenuItem.with_label (_("Notes"));
    details_menu.append (notes_item);
    notes_item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "notes");
      });
    details_menu.show_all ();
    add_detail_button.set_popup (details_menu);
    add_detail_button.set_direction (ArrowType.UP);
    edit_toolbar.add_widget (add_detail_button, true);

    var linked_button = edit_toolbar.add_button (null, _("Linked Accounts"), true) as Gtk.Button;
    var remove_button = edit_toolbar.add_button (null, _("Remove Contact"), false) as Gtk.Button;
    remove_button.clicked.connect (delete_contact);

    edit_toolbar.show_all ();

    edit_revealer = new Revealer ();
    edit_revealer.add (edit_toolbar);
    this.add (edit_revealer);

    edit_revealer.set_no_show_all (true);
    edit_revealer.hide ();

    editor.set_vexpand (true);
    editor.set_hexpand (true);
    top_grid.add (editor);
  }

  void link_contact () {
    var dialog = new LinkDialog (contact);
    dialog.contacts_linked.connect ( (main_contact, linked_contact, operation) => {
      this.contacts_linked (main_contact, linked_contact, operation);
    });
    dialog.show_all ();
  }

  void delete_contact () {
    if (contact != null) {
      contact.hide ();
      this.will_delete (contact);
    }
  }

  void show_no_selection_grid () {
    if ( icon_size_from_name ("ULTRABIG") == 0)
      icon_size_register ("ULTRABIG", 144, 144);

    no_selection_grid = new Grid ();

    var box = new Grid ();
    box.set_orientation (Orientation.VERTICAL);
    box.set_valign (Align.CENTER);
    box.set_halign (Align.CENTER);
    box.set_vexpand (true);
    box.set_hexpand (true);

    var image = new Image.from_icon_name ("avatar-default-symbolic", icon_size_from_name ("ULTRABIG"));
    image.get_style_context ().add_class ("dim-label");
    box.add (image);

    var label = new Gtk.Label ("Select a contact");
    box.add (label);

    no_selection_grid.add (box);
    no_selection_grid.show_all ();
    top_grid.add (no_selection_grid);
  }

  public void set_edit_mode (bool on_edit) {
    if (on_edit) {
      on_edit_mode = true;

      if (contact.has_birthday ())
	birthday_item.hide ();
      else
	birthday_item.show ();

      if (contact.has_nickname ())
	nickname_item.hide ();
      else
	nickname_item.show ();

      if (contact.has_notes ())
	notes_item.hide ();
      else
	notes_item.show ();

      edit_revealer.reveal ();

      sheet.clear ();
      sheet.hide ();

      editor.clear ();
      editor.update (contact);
      editor.show_all ();
    } else {
      on_edit_mode = false;
      /* saving changes */
      foreach (var prop in editor.properties_changed ().entries) {
	Contact.set_persona_property.begin (prop.value.persona, prop.key, prop.value.value,
					    (obj, result) => {
					      try {
						Contact.set_persona_property.end (result);
					      } catch (Error e2) {
						App.app.show_message (e2.message);
						/* FIXME: add this back */
						/* update_sheet (); */
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

      edit_revealer.unreveal ();

      editor.clear ();
      editor.hide ();

      sheet.clear ();
      sheet.update (contact);
    }
  }
}
