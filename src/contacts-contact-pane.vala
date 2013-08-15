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

/* Not available until Vala 0.19 */
extern void gtk_menu_button_set_popup (Gtk.MenuButton button, Gtk.Widget popup);

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

public class Center : Bin {
  public int max_width { get; set; }
  public double xalign { get; set; }

  public Center () {
    this.xalign = 0.5;
  }

  public override void get_preferred_height (out int minimum_height, out int natural_height) {
    var child = get_child ();
    if (child != null) {
      int min;
      int nat;
      child.get_preferred_height (out min, out nat);
      minimum_height = min;
      natural_height = nat;
    } else {
      minimum_height = -1;
      natural_height = -1;
    }
  }

  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    var child = get_child ();
    if (child != null) {
      int min;
      int nat;
      child.get_preferred_width (out min, out nat);
      minimum_width = min;
      natural_width = nat;
    } else {
      minimum_width = -1;
      natural_width = -1;
    }
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    Gtk.Allocation new_alloc;

    set_allocation (allocation);
    new_alloc = allocation;
    if (allocation.width > this.max_width) {
      new_alloc.width = this.max_width;
      new_alloc.x = (int) ((allocation.width - this.max_width) * this.xalign) + allocation.x;
    }

    var child = get_child ();
    child.size_allocate (new_alloc);
  }
}

public class Contacts.ContactPane : Notebook {
  private Store contacts_store;
  public Contact? contact;

  /* 3 pages, first */
  private Frame no_selection_frame;

  /* second page */
  private ContactSheet sheet;

  /* thrid page */
  private ContactEditor editor;
  private Button linked_button;
  private Button remove_button;

  /* single value details */
  private Gtk.MenuItem nickname_item;
  private Gtk.MenuItem birthday_item;
  private Gtk.MenuItem notes_item;

  public bool on_edit_mode;
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
    set_current_page (1);

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

    if (suggestion_grid != null) {
      suggestion_grid.destroy ();
      suggestion_grid = null;
    }

    if (contact != null) {
      contact.personas_changed.disconnect (personas_changed_cb);
      contact.changed.disconnect (contact_changed_cb);
    }

    contact = new_contact;

    update_sheet ();

    bool can_remove = false;
    bool has_links = false;

    if (contact != null) {
      contact.personas_changed.connect (personas_changed_cb);
      contact.changed.connect (contact_changed_cb);

      can_remove = contact.can_remove_personas ();
      has_links = contact.individual.personas.size > 1;
    }

    remove_button.set_sensitive (can_remove);
    linked_button.set_sensitive (has_links);

    if (contact == null)
      show_no_selection_frame ();
  }

  private void personas_changed_cb (Contact contact) {
    update_sheet ();
  }

  private void contact_changed_cb (Contact contact) {
    update_sheet ();
  }

  public ContactPane (Store contacts_store) {
    this.show_tabs = false;

    this.contacts_store = contacts_store;

    /* starts with no_selection_frame 'til someone select something */
    show_no_selection_frame ();

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

    main_sw.add_with_viewport (hcenter);
    sheet.set_focus_vadjustment (main_sw.get_vadjustment ());

    main_sw.get_child ().get_style_context ().add_class ("contacts-main-view");
    main_sw.get_child ().get_style_context ().add_class ("view");

    main_sw.show_all ();
    insert_page (main_sw, null, 1);

    contacts_store.quiescent.connect (() => {
      // Refresh the view when the store is quiescent as we may have missed
      // some potential matches while the store was still preparing.
      update_sheet ();
    });

    suggestion_grid = null;

    /* edit mode widgetry, third page */
    var top_grid = new Grid ();
    top_grid.set_orientation (Orientation.VERTICAL);

    main_sw = new ScrolledWindow (null, null);
    top_grid.add (main_sw);

    main_sw.set_shadow_type (ShadowType.NONE);
    main_sw.set_hexpand (true);
    main_sw.set_vexpand (true);
    main_sw.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

    hcenter = new Center ();
    hcenter.max_width = 600;
    hcenter.xalign = 0.0;

    editor = new ContactEditor ();
    hcenter.add (editor);

    editor.margin = 36;
    editor.set_margin_bottom (24);
    main_sw.add_with_viewport (hcenter);
    editor.set_focus_vadjustment (main_sw.get_vadjustment ());

    main_sw.get_child ().get_style_context ().add_class ("contacts-main-view");
    main_sw.get_child ().get_style_context ().add_class ("view");

    on_edit_mode = false;
    var edit_toolbar = new Toolbar ();
    edit_toolbar.get_style_context ().add_class (STYLE_CLASS_MENUBAR);
    edit_toolbar.get_style_context ().add_class ("contacts-edit-toolbar");
    edit_toolbar.set_vexpand (false);

    var add_detail_button = new Gtk.MenuButton ();
    add_detail_button.set_vexpand (true);
    var box = new Grid ();
    var w = new Label (_("New Detail")) as Widget;
    w.set_valign (Align.CENTER);
    w.set_vexpand (true);
    box.set_column_spacing (4);
    box.add (w);
    w = new Arrow (ArrowType.DOWN, ShadowType.OUT) as Widget;
    w.set_valign (Align.CENTER);
    w.set_vexpand (true);
    box.add (w);
    add_detail_button.add (box);
    var details_menu = new Gtk.Menu ();
    details_menu.set_halign (Align.START);

    /* building menu */
    var item = new Gtk.MenuItem.with_label (_("Personal email"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "email-addresses", "PERSONAL");
      });
    item = new Gtk.MenuItem.with_label (_("Work email"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "email-addresses", "WORK");
      });

    item = new Gtk.MenuItem.with_label (_("Mobile phone"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "phone-numbers", "CELL");
      });
    item = new Gtk.MenuItem.with_label (_("Home phone"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "phone-numbers", "HOME");
      });
    item = new Gtk.MenuItem.with_label (_("Work phone"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "phone-numbers", "WORK");
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

    item = new Gtk.MenuItem.with_label (_("Home address"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "postal-addresses", "HOME");
      });
    item = new Gtk.MenuItem.with_label (_("Work address"));
    details_menu.append (item);
    item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "postal-addresses", "WORK");
      });

    notes_item = new Gtk.MenuItem.with_label (_("Notes"));
    details_menu.append (notes_item);
    notes_item.activate.connect (() => {
	editor.add_new_row_for_property (contact.find_primary_persona (), "notes");
      });
    details_menu.show_all ();
    /* Not available until Vala 0.19 */
    //add_detail_button.set_popup (details_menu);
    gtk_menu_button_set_popup (add_detail_button, details_menu);
    add_detail_button.set_direction (ArrowType.UP);

    var tool_item = new ToolItem ();
    tool_item.add (add_detail_button);
    tool_item.margin_right = 12;
    edit_toolbar.insert (tool_item, -1);

    tool_item = new ToolItem ();
    linked_button = new Button.with_label (_("Linked Accounts"));
    linked_button.set_vexpand (true);
    tool_item.add (linked_button);
    edit_toolbar.insert (tool_item, -1);
    linked_button.clicked.connect (linked_accounts);

    tool_item = new SeparatorToolItem ();
    tool_item.set_expand (true);
    (tool_item as SeparatorToolItem).set_draw (false);
    edit_toolbar.insert (tool_item, -1);

    tool_item = new ToolItem ();
    remove_button = new Button.with_label (_("Remove Contact"));
    remove_button.set_vexpand (true);
    tool_item.add (remove_button);
    edit_toolbar.insert (tool_item, -1);
    remove_button.clicked.connect (delete_contact);

    edit_toolbar.show_all ();
    top_grid.add (edit_toolbar);

    editor.set_vexpand (true);
    editor.set_hexpand (true);
    editor.show_all ();
    main_sw.show ();
    top_grid.show_all ();
    insert_page (top_grid, null, 2);
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
      set_edit_mode (false);

      this.will_delete (contact);

      show_contact (null);
    }
  }

  void show_no_selection_frame () {
    if ( icon_size_from_name ("ULTRABIG") == 0) {
      icon_size_register ("ULTRABIG", 144, 144);

      no_selection_frame = new Frame (null);
      no_selection_frame.set_shadow_type (ShadowType.NONE);
      no_selection_frame.set_size_request (500, -1);

      var box = new Grid ();
      box.set_orientation (Orientation.VERTICAL);
      box.set_valign (Align.CENTER);
      box.set_halign (Align.CENTER);
      box.set_vexpand (true);
      box.set_hexpand (true);

      var image = new Image.from_icon_name ("avatar-default-symbolic", icon_size_from_name ("ULTRABIG"));
      image.get_style_context ().add_class ("dim-label");
      box.add (image);

      var label = new Gtk.Label (_("Select a contact"));
      box.add (label);

      no_selection_frame.add (box);
      no_selection_frame.show_all ();
      insert_page (no_selection_frame, null, 0);
    }

    set_current_page (0);
  }

  public void set_edit_mode (bool on_edit) {
    if (on_edit == on_edit_mode)
      return;

    if (on_edit) {
      if (contact == null) {
	return;
      }

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

      editor.clear ();

      sheet.clear ();
      sheet.update (contact);
      set_current_page (1);
    }
  }
}
