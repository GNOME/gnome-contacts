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

public class Contacts.ContactSheet : Grid {

  const int PROFILE_SIZE = 128;

  public ContactSheet () {
    set_row_spacing (12);
    set_column_spacing (16);
  }

  public void update (Contact c) {
    var image_frame = new ContactFrame (PROFILE_SIZE, true);
    image_frame.set_vexpand (false);
    image_frame.set_valign (Align.START);
    c.keep_widget_uptodate (image_frame,  (w) => {
	(w as ContactFrame).set_image (c.individual, c);
      });
    attach (image_frame,  0, 0, 1, 3);

    var name_label = new Label (null);
    name_label.set_hexpand (true);
    name_label.set_halign (Align.START);
    name_label.set_valign (Align.START);
    name_label.set_margin_top (4);
    name_label.set_ellipsize (Pango.EllipsizeMode.END);
    name_label.xalign = 0.0f;

    c.keep_widget_uptodate (name_label, (w) => {
	(w as Label).set_markup (Markup.printf_escaped ("<span font='16'>%s</span>", c.display_name));
      });
    attach (name_label,  1, 0, 1, 1);

    var merged_presence = c.create_merged_presence_widget ();
    merged_presence.set_halign (Align.START);
    merged_presence.set_valign (Align.START);
    attach (merged_presence,  1, 1, 1, 1);

    int i = 3;
    int last_store_position = 0;
    PersonaStore last_store = null;

    var personas = c.get_personas_for_display ();
    /* Cause personas are sorted properly I can do this */
    foreach (var p in personas) {
      if (! Contact.persona_is_main (p) && p.store != last_store) {
	var store_name = new Label("");
	store_name.set_markup (Markup.printf_escaped ("<span font='16px bold'>%s</span>",
						      Contact.format_persona_store_name_for_contact (p)));
	store_name.set_halign (Align.START);
	store_name.xalign = 0.0f;
	store_name.margin_left = 6;
	attach (store_name, 0, i, 1, 1);
	last_store = p.store;
	last_store_position = ++i;
      }

      /* emails first */
      var details = p as EmailDetails;
      if (details != null) {
	var emails = Contact.sort_fields<EmailFieldDetails>(details.email_addresses);
	foreach (var email in emails) {
	  var type_label = new Label (TypeSet.general.format_type (email));
	  type_label.xalign = 1.0f;
	  type_label.set_halign (Align.END);
	  type_label.get_style_context ().add_class ("dim-label");
	  attach (type_label, 0, i, 1, 1);

	  var value_label = new Button.with_label (email.value);
	  value_label.focus_on_click = false;
	  value_label.relief = ReliefStyle.NONE;
	  value_label.xalign = 0.0f;
	  value_label.set_hexpand (true);
	  attach (value_label, 1, i, 1, 1);
	  i++;

	  value_label.clicked.connect (() => {
	      Utils.compose_mail ("%s <%s>".printf(c.display_name, email.value));
	    });
	}
      }

      /* phones then */
      var phone_details = p as PhoneDetails;
      if (phone_details != null) {
	var phones = Contact.sort_fields<PhoneFieldDetails>(phone_details.phone_numbers);
	foreach (var phone in phones) {
	  var type_label = new Label (TypeSet.general.format_type (phone));
	  type_label.xalign = 1.0f;
	  type_label.set_halign (Align.END);
	  type_label.get_style_context ().add_class ("dim-label");
	  attach (type_label, 0, i, 1, 1);

	  Widget value_label;
	  if (App.app.contacts_store.can_call) {
	    value_label = new Button.with_label (phone.value);
	    value_label.set_hexpand (true);
	    (value_label as Button).focus_on_click = false;
	    (value_label as Button).relief = ReliefStyle.NONE;

	    (value_label as Button).clicked.connect (() => {
		Utils.start_call (phone.value, App.app.contacts_store.calling_accounts);
	      });
	  } else {
	    value_label = new Label (phone.value);
	    value_label.set_halign (Align.START);
	    /* FXIME: hardcode gap to match the button-label starting */
	    value_label.margin_left = 6;
	  }

	  attach (value_label, 1, i, 1, 1);
	  i++;

	}
      }

      if (i == last_store_position) {
	get_child_at (0, i - 1).destroy ();
      }
    }

    show_all ();
  }

  public void clear () {
    foreach (var w in get_children ()) {
      w.destroy ();
    }
  }
}

public class Contacts.ContactPane : ScrolledWindow {
  private Store contacts_store;
  public Contact? contact;

  private Grid top_grid;
  private ContactSheet sheet; /* Eventually replace top_grid with sheet */

  private Grid no_selection_grid;

  public Grid suggestion_grid;

  /* Signals */
  public signal void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation);
  public signal void will_delete (Contact contact);

  /* Tries to set the property on all persons that have it writeable, and
   * if none, creates a new persona and writes to it, returning the new
   * persona.
   */
  private async Persona? set_individual_property (Contact contact,
						  string property_name,
						  Value value) throws GLib.Error, PropertyError {
    bool did_set = false;
    // Need to make a copy here as it could change during the yields
    var personas_copy = contact.individual.personas.to_array ();
    foreach (var p in personas_copy) {
      if (property_name in p.writeable_properties) {
	did_set = true;
	yield Contact.set_persona_property (p, property_name, value);
      }
    }

    if (!did_set) {
      var fake = new FakePersona (contact);
      return yield fake.make_real_and_set (property_name, value);
    }
    return null;
  }

  private void change_avatar (ContactFrame image_frame) {
    var dialog = new AvatarDialog (contact);
    dialog.show ();
    dialog.set_avatar.connect ( (icon) =>  {
	Value v = Value (icon.get_type ());
	v.set_object (icon);
	set_individual_property.begin (contact,
				       "avatar", v,
				       (obj, result) => {
					 try {
					   set_individual_property.end (result);
					 } catch (Error e) {
					   App.app.show_message (e.message);
					   image_frame.set_image (contact.individual, contact);
					 }
				       });
      });
  }

  public void update_sheet (bool show_matches = true) {
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
    c.keep_widget_uptodate (image_frame,  (w) => {
	(w as ContactFrame).set_image (c.individual, c);
      });
    image_frame.set_hexpand (false);
    image_frame.margin = 24;
    image_frame.margin_right = 12;
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

  public void show_contact (Contact? new_contact, bool edit=false, bool show_matches = true) {
    if (contact == new_contact)
      return;

    if (contact != null) {
      contact.personas_changed.disconnect (personas_changed_cb);
      contact.changed.disconnect (contact_changed_cb);
    }

    contact = new_contact;

    if (contact != null)
      no_selection_grid.destroy ();

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
    /* FIXME: what to do here ? */
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
    } else {
      /* FIXME, uncomment */
      // var store = new ListStore (2, typeof (string), typeof (ImValue?));
      // foreach (var value in online_personas) {
      // 	TreeIter iter;
      // 	store.append (out iter);
      // 	store.set (iter, 0, value.name, 1, value);
      // }
      // TreeSelection selection;
      // var dialog = pick_one_dialog (_("Select chat account"), store, out selection);
      // dialog.response.connect ( (response) => {
      // 	  if (response == ResponseType.OK) {
      // 	    ImValue? value2;
      // 	    TreeIter iter2;

      // 	    if (selection.get_selected (null, out iter2)) {
      // 	      store.get (iter2, 1, out value2);
      // 	      Utils.start_chat (contact, value2.protocol, value2.id);
      // 	    }
      // 	  }
      // 	  dialog.destroy ();
      // 	});
    }
  }

  public ContactPane (Store contacts_store) {
    this.get_style_context ().add_class ("contacts-content");
    this.set_shadow_type (ShadowType.IN);

    this.set_hexpand (true);
    this.set_vexpand (true);
    this.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

    this.contacts_store = contacts_store;

    top_grid = new Grid ();
    top_grid.set_orientation (Orientation.VERTICAL);
    top_grid.margin = 36;
    top_grid.set_margin_bottom (24);
    top_grid.set_row_spacing (20);
    this.add_with_viewport (top_grid);
    top_grid.set_focus_vadjustment (this.get_vadjustment ());

    this.get_child().get_style_context ().add_class ("contacts-main-view");
    this.get_child().get_style_context ().add_class ("view");

    sheet = new ContactSheet ();
    sheet.set_orientation (Orientation.VERTICAL);
    top_grid.add (sheet);

    top_grid.show_all ();

    contacts_store.quiescent.connect (() => {
      // Refresh the view when the store is quiescent as we may have missed
      // some potential matches while the store was still preparing.
      /* FIXME, uncomment */
      // update_properties ();
    });

    suggestion_grid = null;

    show_no_selection_grid ();
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
}
