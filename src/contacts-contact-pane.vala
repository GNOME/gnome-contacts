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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

using Gtk;
using Folks;
using Gee;

class Contacts.DetailsLayout : Object {
  public struct State {
    private bool expands;
    public Grid? current_row;
    Widget? last_label;
  }

  public DetailsLayout (Grid fields_grid) {
    this.fields_grid = fields_grid;
    label_size_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
  }

  Grid fields_grid;
  SizeGroup label_size_group;

  private bool expands;
  public Grid? current_row;
  Widget? last_label;
  Box? detail_box;

  public void reset (bool full) {
    foreach (var w in fields_grid.get_children ()) {
      if (full || !w.get_data<bool> ("contacts-stable"))
	w.destroy ();
    }
    current_row = null;
    last_label = null;
  }

  public void mark_row_stable () {
    current_row.set_data<bool> ("contacts-stable", true);
  }

  void new_row () {
    var grid = new Grid ();
    expands = false;
    last_label = null;
    grid.set_row_spacing (9);
    grid.set_column_spacing (3);
    grid.set_orientation (Orientation.HORIZONTAL);
    if (current_row != null) {
      Utils.grid_insert_row_after (fields_grid, current_row, true);
      fields_grid.attach_next_to (grid, current_row, PositionType.BOTTOM, 1, 1);
    } else
      fields_grid.add (grid);
    current_row = grid;
  }

  public void add_widget_label (Widget w) {
    new_row ();

    label_size_group.add_widget (w);
    current_row.add (w);
  }

  public void add_label (string label) {
    var l = new Label (label);
    l.set_markup ("<b>" + label + "</b>");
    l.get_style_context ().add_class ("dim-label");
    l.set_alignment (1, 0.5f);

    add_widget_label (l);
  }

  public void begin_detail_box () {
    var box = new Box (Orientation.VERTICAL, 0);
    attach_detail (box);
    detail_box = box;
  }

  public void end_detail_box () {
    detail_box = null;
  }

  public void attach_detail (Widget widget) {
    if (detail_box != null)
      detail_box.add (widget);
    else if (last_label != null)
      current_row.attach_next_to (widget, last_label, PositionType.BOTTOM, 1, 1);
    else
      current_row.add (widget);

    widget.show ();
    last_label = widget;
  }

  public void add_detail (string val) {
    var label = new Label (val);
    label.set_selectable (true);
    label.set_valign (Align.CENTER);
    label.set_halign (Align.START);
    label.set_ellipsize (Pango.EllipsizeMode.END);
    label.xalign = 0.0f;

    attach_detail (label);
  }

  public Entry add_entry (string val) {
    var entry = new Entry ();
    entry.get_style_context ().add_class ("contact-entry");
    entry.set_text (val);
    entry.set_valign (Align.CENTER);
    entry.set_halign (Align.FILL);
    entry.set_hexpand (true);
    expands = true;

    attach_detail (entry);
    return entry;
  }

  public void add_label_detail (string label, string val) {
    add_label (label);
    add_detail (val);
  }

  public void add_link (string uri, string text) {
    var v = new LinkButton.with_label (uri, text);
    v.set_valign (Align.CENTER);
    v.set_halign (Align.START);
    Label l = v.get_child () as Label;
    l.set_ellipsize (Pango.EllipsizeMode.END);
    l.xalign = 0.0f;


    attach_detail (v);
  }

  public Button add_button (string? icon, bool at_top = true) {
    var button = new Button ();
    button.set_valign (Align.CENTER);
    button.set_halign (Align.END);
    if (!expands)
      button.set_hexpand (true);

    if (icon != null) {
      var image = new Image();
      image.set_from_icon_name (icon, IconSize.MENU);
      button.add (image);
      image.show ();
    }

    if (at_top || last_label == null)
      current_row.add (button);
    else
      current_row.attach_next_to (button, last_label, PositionType.RIGHT, 1, 1);

    return button;
  }

  public Button add_remove (bool at_top = true) {
    var button = add_button ("edit-delete-symbolic", at_top);
    button.set_relief (ReliefStyle.NONE);
    return button;
  }

  public State? save_state () {
    State? state = State();
    state.expands = expands;
    state.current_row = current_row;
    state.last_label = last_label;
    return state;
  }

  public void load_state (State? state) {
    expands = state.expands;
    current_row = state.current_row;
    last_label = state.last_label;
  }
}

public class Contacts.ContactFrame : Frame {
  private int size;
  private string? text;
  private Gdk.Pixbuf? pixbuf;
  private Pango.Layout? layout;
  private int text_height;

  public ContactFrame (int size) {
    this.size = size;

    var image = new Image ();
    image.set_size_request (size, size);
    this.add (image);
    set_shadow_type (ShadowType.NONE);
  }

  public void set_image (AvatarDetails? details, Contact? contact = null) {
    pixbuf = null;
    if (details != null &&
	details.avatar != null) {
      try {
	var stream = details.avatar.load (size, null);
	pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, size, size, true);
      }
      catch {
      }
    }

    if (pixbuf == null) {
      pixbuf = Contact.draw_fallback_avatar (size, contact);
    }
    pixbuf = Contact.frame_icon (pixbuf);
  }

  public void set_text (string? text_, int text_height_) {
    text = text_;
    text_height = text_height_;
    layout = null;
    if (text != null) {
      layout = create_pango_layout (text);
      Pango.Rectangle rect = {0 };
      int font_size = text_height - /* Y PADDING */ 4 +  /* Removed below */ 1;

      do {
	font_size = font_size - 1;
	var fd = new Pango.FontDescription();
	fd.set_absolute_size (font_size*Pango.SCALE);
	layout.set_font_description (fd);
	layout.get_extents (null, out rect);
      } while (rect.width > size * Pango.SCALE);
    }
  }

  public override bool draw (Cairo.Context cr) {
    cr.save ();

    if (pixbuf != null) {
      Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
      cr.paint();
    }

    if (layout != null) {
      Utils.cairo_rounded_box (cr, 0, 0, size, size, 4);
      cr.clip ();

      cr.set_source_rgba (0, 0, 0, 0.5);
      cr.rectangle (0, size - text_height, size, text_height);
      cr.fill ();

      cr.set_source_rgb (1.0, 1.0, 1.0);
      Pango.Rectangle rect;
      layout.get_extents (null, out rect);
      double label_width = rect.width/(double)Pango.SCALE;
      double label_height = rect.height / (double)Pango.SCALE;
      cr.move_to (Math.round ((size - label_width) / 2.0),
		  size - text_height + Math.floor ((text_height - label_height) / 2.0));
      Pango.cairo_show_layout (cr, layout);
    }
    cr.restore ();

    base.draw (cr);
    return true;
  }
}

public class Contacts.PersonaButton : RadioButton {
  private Widget create_image (AvatarDetails? details, int size) {
    var image = new Image ();
    image.set_padding (2, 2);

    Gdk.Pixbuf pixbuf = null;
    if (details != null &&
	details.avatar != null) {
      try {
	var stream = details.avatar.load (size, null);
	pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, size, size, true);
      }
      catch {
      }
    }

    if (pixbuf == null) {
      pixbuf = Contact.draw_fallback_avatar (size, null);
    }

    if (pixbuf != null) {
      image.set_from_pixbuf (Contact.frame_icon (pixbuf));
    }

    image.draw.connect ( (cr) => {
	if (this.get_active ()) {
	  cr.save ();
	  cr.set_source_rgba (0x74/255.0, 0xa0/255.0, 0xd0/255.0, 0.5);
	  Utils.cairo_rounded_box (cr, 0, 0, size+4, size+4, 4+2);
	  Utils.cairo_rounded_box (cr, 2, 2, size, size, 4);
	  cr.set_fill_rule (Cairo.FillRule.EVEN_ODD);
	  cr.fill ();
	  cr.restore ();
	}
	return false;
      });

    return image;
  }


  public PersonaButton (RadioButton? group, AvatarDetails? avatar, int size) {
    if (group != null)
      join_group (group);

    get_style_context ().add_class ("contact-button");
    set_can_default (false);
    var image = create_image (avatar, size);
    add (image);
    set_mode (false);
  }
}


public class Contacts.ContactPane : EventBox {
  private enum DisplayMode {
    INITIAL,
    EMPTY,
    DETAILS,
    NOTES,
    EDIT
  }
  private Store contacts_store;
  private Contact? selected_contact;
  private Persona? editing_persona;
  private DisplayMode display_mode;
  private Grid fields_grid;
  private bool has_notes;
  private Widget notes_dot;
  private ButtonBox normal_buttons;
  private ButtonBox editing_buttons;
  private DetailsLayout layout;

  HashSet<EmailFieldDetails> editing_emails;
  HashSet<PhoneFieldDetails> editing_phones;
  HashSet<UrlFieldDetails> editing_urls;
  HashSet<PostalAddressFieldDetails> editing_postals;

  const int PROFILE_SIZE = 96;
  const int LABEL_HEIGHT = 20;

  private signal void save_data ();

  private void update_detail_property (string property_name,
				       Set<AbstractFieldDetails> detail_set) {
    var editing_backup = editing_persona;
    if (editing_persona is FakePersona) {
      var c = selected_contact;
      c.ensure_primary_persona.begin ( (obj, result) => {
	  try {
	    var p = c.ensure_primary_persona.end (result);
	    p.set (property_name, detail_set);
	    /* HACK: We don't seem to get any callbacks from folks when the actual
	     * new property value is availibile, so we add a small timeout here...
	     * I'm very sorry...
	     */
	    Timeout.add (100, () => {
		if (c == selected_contact && display_mode == DisplayMode.EDIT &&
		    editing_persona == editing_backup) {
		  display_edit (selected_contact, p, false);
		}
		return false;
	      });
	  } catch (Error e) {
	    warning ("Unable to create writable persona: %s", e.message);
	  }
	});
    } else {
      editing_persona.set (property_name, detail_set);
    }
  }

  private void update_edit_detail_type (Set<AbstractFieldDetails> detail_set,
					AbstractFieldDetails detail,
					TypeCombo combo,
					string property_name) {
    combo.update_details (detail);
    update_detail_property (property_name, detail_set);
  }

  private void add_detail_combo (TypeSet type_set,
				 Set<AbstractFieldDetails> detail_set,
				 AbstractFieldDetails detail,
				 string property_name) {
    var combo = new TypeCombo (type_set);
    combo.set_halign (Align.FILL);
    combo.set_hexpand (false);
    combo.set_active (detail);
    layout.add_widget_label (combo);

    combo.changed.connect ( () => {
	update_edit_detail_type (detail_set, detail, combo, property_name);
      });
  }

  private void update_edit_detail_string_value (Set<AbstractFieldDetails<string>> detail_set,
						AbstractFieldDetails<string> detail,
						Entry entry,
						string property_name) {
    if (detail.value != entry.get_text ()) {
      detail.value = entry.get_text ();

      update_detail_property (property_name, detail_set);
    }
  }

  private Entry add_detail_entry (Set<AbstractFieldDetails> detail_set,
				  AbstractFieldDetails<string> detail,
				  string property_name,
				  string? placeholder_text) {
    var entry = layout.add_entry (detail.value);
    if (placeholder_text != null)
      entry.set ("placeholder-text", placeholder_text);

    entry.focus_out_event.connect ( (ev) => {
	update_edit_detail_string_value (detail_set, detail, entry, property_name);
	return false;
      });
    return entry;
  }

  private void update_edit_detail_postal_value (Set<PostalAddressFieldDetails> detail_set,
						PostalAddressFieldDetails detail,
						Entry entry,
						string subproperty_name,
						string property_name) {
    string old_value;
    detail.value.get (subproperty_name, out old_value);
    if (old_value != entry.get_text ()) {
      var new_value = new PostalAddress (detail.value.po_box,
					 detail.value.extension,
					 detail.value.street,
					 detail.value.locality,
					 detail.value.region,
					 detail.value.postal_code,
					 detail.value.country,
					 detail.value.address_format,
					 detail.value.uid);
      new_value.set (subproperty_name, entry.get_text ());
      detail.value = new_value;

      update_detail_property (property_name, detail_set);
    }
  }

  private Entry add_detail_postal_entry (Set<PostalAddressFieldDetails> detail_set,
					 PostalAddressFieldDetails detail,
					 string subproperty_name,
					 string property_name,
					 string? placeholder_text) {
    string postal_part;
    detail.value.get (subproperty_name, out postal_part);
    var entry = layout.add_entry (postal_part);
    entry.get_style_context ().add_class ("contact-postal-entry");
    if (placeholder_text != null)
      entry.set ("placeholder-text", placeholder_text);

    entry.focus_out_event.connect ( (ev) => {
	update_edit_detail_postal_value (detail_set, detail, entry, subproperty_name, property_name);
	return false;
	});

    return entry;
  }

  private Button add_detail_remove (Set<AbstractFieldDetails> detail_set,
				  AbstractFieldDetails detail,
				  string property_name,
				  bool at_top = true) {
    var remove_button = layout.add_remove (at_top);
    var row = layout.current_row;

    remove_button.clicked.connect ( () => {
	detail_set.remove (detail);
	update_detail_property (property_name, detail_set);
	row.destroy ();
      });
    return remove_button;
  }

  private void add_detail_editor (TypeSet type_set,
				  Set<AbstractFieldDetails> detail_set,
				  AbstractFieldDetails<string> detail,
				  string property_name,
				  string? placeholder_text) {
    detail_set.add (detail);
    add_detail_combo (type_set, detail_set, detail, property_name);
    add_detail_entry (detail_set, detail, property_name, placeholder_text);
    add_detail_remove (detail_set, detail, property_name);
  }

  private void add_detail_editor_no_type (Set<AbstractFieldDetails> detail_set,
					   AbstractFieldDetails<string> detail,
					   string property_name,
					   string? placeholder_text) {
    detail_set.add (detail);
    add_detail_entry (detail_set, detail, property_name, placeholder_text);
    add_detail_remove (detail_set, detail, property_name, false);
  }

  private void add_postal_editor (Set<PostalAddressFieldDetails> detail_set,
				  PostalAddressFieldDetails detail) {
    string[] props = {"street", "extension", "locality", "region", "postal_code", "po_box", "country"};
    string[] nice = {_("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

    detail_set.add (detail);
    add_detail_combo (TypeSet.general, detail_set, detail, "postal_addresses");

    layout.begin_detail_box ();
    for (int i = 0; i < props.length; i++) {
      add_detail_postal_entry (detail_set,
			       detail,
			       props[i],
			       "postal_addresses",
			       nice[i]);
    }
    layout.end_detail_box ();
    var button = add_detail_remove (detail_set, detail, "postal_addresses");
    button.set_valign (Align.START);
  }

  private void update_edit_details (ContactFrame image_frame, Persona persona, bool new_contact) {
    editing_persona = persona;
    layout.reset (false);
    image_frame.set_image (persona as AvatarDetails);
    image_frame.set_text (Contact.format_persona_store_name (persona.store), LABEL_HEIGHT);

    editing_emails = new HashSet<EmailFieldDetails>();
    editing_phones = new HashSet<PhoneFieldDetails>();
    editing_urls = new HashSet<UrlFieldDetails>();
    editing_postals = new HashSet<PostalAddressFieldDetails>();

    var email_details = persona as EmailDetails;
    if (email_details != null) {
      var emails = Contact.sort_fields<EmailFieldDetails>(email_details.email_addresses);
      foreach (var email in emails) {
	add_detail_editor (TypeSet.general,
			   editing_emails, new EmailFieldDetails (email.value, email.parameters),
			   "email_addresses",
			   _("Enter email address"));
      }
    }

    if (new_contact)
      add_detail_editor (TypeSet.general,
			 editing_emails, new EmailFieldDetails(""),
			 "email_addresses",
			 _("Enter email address"));

    var im_details = persona as ImDetails;
    if (im_details != null) {
      var ims = im_details.im_addresses;
      var im_keys = ims.get_keys ();
      if (!im_keys.is_empty) {
	foreach (var protocol in im_keys) {
	  foreach (var id in ims[protocol]) {
	    layout.add_label_detail (_("Chat"), protocol + "/" + id.value);
	    var button = layout.add_remove ();
	    button.set_sensitive (false);
	  }
	}
      }
    }

    var phone_details = persona as PhoneDetails;
    if (phone_details != null) {
      var phone_numbers = Contact.sort_fields<PhoneFieldDetails>(phone_details.phone_numbers);
      foreach (var p in phone_numbers) {
	add_detail_editor (TypeSet.phone,
			   editing_phones, new PhoneFieldDetails (p.value, p.parameters),
			   "phone_numbers",
			   _("Enter phone number"));
      }
    }

    if (new_contact)
      add_detail_editor (TypeSet.phone,
			 editing_phones, new PhoneFieldDetails(""),
			 "phone_numbers",
			 _("Enter phone number"));

    var postal_details = persona as PostalAddressDetails;
    if (postal_details != null) {
      var postals = postal_details.postal_addresses;
      foreach (var _addr in postals) {
	add_postal_editor (editing_postals,
			   new PostalAddressFieldDetails(_addr.value, _addr.parameters));
      }
    }

    DetailsLayout.State? url_row = null;
    var urls_details = persona as UrlDetails;
    if (urls_details != null) {
      var urls = urls_details.urls;
      if (!urls.is_empty) {
	layout.add_label ("Links");
	foreach (var url_details in urls) {
	  add_detail_editor_no_type (editing_urls,
				     new UrlFieldDetails (url_details.value, url_details.parameters),
				     "urls",
				     _("Enter phone number"));
	}
	url_row = layout.save_state ();
      }
    }

    var end_row = layout.save_state ();

    if (persona.store.is_writeable) {
      layout.add_label ("");
      var menu_button = new MenuButton (_("Add detail"));
      menu_button.set_hexpand (false);
      menu_button.set_margin_top (12);

      var menu = new Menu ();
      Utils.add_menu_item (menu, _("Email")).activate.connect ( () => {
	  layout.load_state (end_row);
	  add_detail_editor (TypeSet.general,
			     editing_emails, new EmailFieldDetails(""),
			     "email_addresses",
			     _("Enter email address"));
	  fields_grid.show_all ();
	  end_row = layout.save_state ();
	});
      Utils.add_menu_item (menu, _("Phone number")).activate.connect ( () => {
	  layout.load_state (end_row);
	  add_detail_editor (TypeSet.phone,
			     editing_phones, new PhoneFieldDetails(""),
			     "phone_numbers",
			     _("Enter phone number"));
	  fields_grid.show_all ();
	  end_row = layout.save_state ();
	});
      Utils.add_menu_item (menu, _("Postal Address")).activate.connect ( () => {
	  layout.load_state (end_row);
	  add_postal_editor (editing_postals,
			     new PostalAddressFieldDetails(new PostalAddress (null, null, null, null, null, null, null, null, null), null));
	  fields_grid.show_all ();
	  end_row = layout.save_state ();
	});
      Utils.add_menu_item (menu,_("Link")).activate.connect ( () => {
	  if (url_row != null) {
	    layout.load_state (url_row);
	  } else {
	    layout.add_label ("Links");
	  }
	  add_detail_editor_no_type (editing_urls,
				     new UrlFieldDetails(""),
				     "urls",
				     _("Enter link"));
	  url_row = layout.save_state ();
	  fields_grid.show_all ();
	  });

      menu_button.set_menu (menu);

      layout.attach_detail (menu_button);
    }


    fields_grid.show_all ();
  }

  private void display_card (Contact contact) {
    var image_frame = new ContactFrame (PROFILE_SIZE);
    image_frame.set_image (contact.individual, contact);
    // Put the frame in a grid so its not expanded by the size-group
    var ig = new Grid ();
    ig.add (image_frame);
    layout.add_widget_label (ig);

    layout.current_row.set_vexpand (false);
    var g = new Grid();
    layout.current_row.add (g);

    var l = new Label (null);
    l.set_markup ("<span font='22'><b>" + contact.display_name + "</b></span>");
    l.set_hexpand (true);
    l.set_halign (Align.START);
    l.set_valign (Align.START);
    l.set_ellipsize (Pango.EllipsizeMode.END);
    l.xalign = 0.0f;
    g.attach (l,  0, 0, 1, 1);

    var nick = contact.individual.nickname;
    if (nick != null && nick.length > 0) {
      l = new Label ("\xE2\x80\x9C" + nick + "\xE2\x80\x9D");
      l.set_halign (Align.START);
      l.set_valign (Align.START);
      l.set_ellipsize (Pango.EllipsizeMode.END);
      l.xalign = 0.0f;
      g.attach (l,  0, 1, 1, 1);
    }

    /* TODO:
    l = new Label ("<title>, <Company>");
    l.set_halign (Align.START);
    l.set_valign (Align.START);
    l.set_ellipsize (Pango.EllipsizeMode.END);
    l.xalign = 0.0f;
    g.attach (l,  0, 2, 1, 1);
    */

    var merged_presence = contact.create_merged_presence_widget ();
    merged_presence.set_halign (Align.START);
    merged_presence.set_valign (Align.END);
    merged_presence.set_vexpand (true);
    g.attach (merged_presence,  0, 3, 1, 1);
  }

  private void save_notes (Gee.HashMultiMap<Persona?,TextView> widgets) {
    // Update notes on all personas if one of the textviews for that persona changed
    // Also note that the individual might not have a persona on the main store, so
    // it would need to add one and link the individual into it

    foreach (var persona in widgets.get_keys ()) {
      bool modified = false;

      var notes = new HashSet<NoteFieldDetails> ();
      foreach (var view in widgets.get (persona)) {
	if (view.get_buffer ().get_modified ())
	  modified = true;
	string? uid = view.get_data<string?> ("uid");
	TextIter start, end;
	view.get_buffer ().get_start_iter (out start);
	view.get_buffer ().get_end_iter (out end);
	var text = view.get_buffer ().get_text (start, end, true);
	if (text.length > 0) {
	  var note = new NoteFieldDetails (text, null, uid);
	  notes.add (note);
	}
      }

      if (modified) {
	if (persona == null) {
	  var c = selected_contact;
	  c.ensure_primary_persona.begin ( (obj, result) => {
	      try {
		var p = c.ensure_primary_persona.end (result);
		if (p is NoteDetails)
		  (p as NoteDetails).notes = notes;
		else
		  warning ("Writable store doesn't support notes");
	      } catch (Error e) {
		warning ("Unable to create writable persona: %s", e.message);
	      }
	    });
	} else {
	  (persona as NoteDetails).notes = notes;
	}
      }
    }
  }

  private TextView add_note () {
    var text = new TextView ();
    text.set_hexpand (true);
    text.set_vexpand (true);
    var scrolled = new ScrolledWindow (null, null);
    scrolled.set_shadow_type (ShadowType.OUT);
    scrolled.add_with_viewport (text);
    fields_grid.add (scrolled);
    return text;
  }

  private void update_note (TextView text, NoteFieldDetails note) {
    text.get_buffer ().set_text (note.value);
    text.get_buffer ().set_modified (false);
    text.set_data<string?> ("uid", note.uid);
  }

  private void display_notes () {
    set_display_mode (DisplayMode.NOTES);
    display_card (selected_contact);

    var widgets = new HashMultiMap<Persona?, TextView>();
    var main_text = add_note ();

    Persona? primary_persona = selected_contact.find_primary_persona ();
    if (primary_persona == null || primary_persona is NoteDetails)
      widgets.set (primary_persona, main_text);
    else
      warning ("Writable store doesn't support notes");

    bool primary_note_seen = false;

    foreach (var persona in selected_contact.individual.personas) {
      var notes = persona as NoteDetails;
      if (notes == null)
	continue;
      foreach (var note in notes.notes) {
	if (persona == primary_persona && !primary_note_seen) {
	  primary_note_seen = true;
	  update_note (main_text, note);
	} else if (persona.store.is_writeable) {
	  var text = add_note ();
	  update_note (text, note);
	  widgets.set (persona, text);
	} else {
	  var label = new Label (note.value);
	  label.set_halign (Align.START);
	  fields_grid.add (label);
	}
      }
    }

    fields_grid.show_all ();

    ulong id = 0;
    id = this.save_data.connect ( () => {
	save_notes (widgets);
	this.disconnect (id);
      });
  }

  private void display_edit (Contact contact, Persona? _persona, bool new_contact = false) {
    Persona? persona = _persona;
    set_display_mode (DisplayMode.EDIT);

    var image_frame = new ContactFrame (PROFILE_SIZE);
    // Put the frame in a grid so its not expanded by the size-group
    var ig = new Grid ();
    ig.add (image_frame);
    layout.add_widget_label (ig);
    layout.mark_row_stable ();

    layout.current_row.set_vexpand (false);
    var g = new Grid();
    layout.current_row.add (g);

    var e = new Entry ();
    e.get_style_context ().add_class ("contact-entry");
    e.set ("placeholder-text", _("Enter name"));
    e.set_data ("original-text", contact.display_name);
    e.set_text (contact.display_name);
    e.set_hexpand (true);
    e.set_halign (Align.START);
    e.set_valign (Align.START);
    g.attach (e,  0, 0, 1, 1);
    if (new_contact)
      e.grab_focus ();

    e.focus_out_event.connect ( (ev) => {
	name = e.get_text ();
	bool name_set = false;
	if (name != e.get_data<string?> ("original-text")) {
	  foreach (var p in contact.individual.personas) {
	    if (p is NameDetails &&
		p.store.is_writeable) {
	      (p as NameDetails).full_name = name;
	      name_set = true;
	    }
	  }

	  if (!name_set) {
	    // TODO: Create a writable persona so we can set the name
	    warning ("Didn't find a writable persona to store the name");
	  }
	}
	return false;
      });

    var personas = new Grid ();
    personas.set_row_spacing (0);
    personas.set_halign (Align.START);
    personas.set_valign (Align.END);
    personas.set_vexpand (true);

    var persona_list = new ArrayList<Persona>();
    int i = 0;
    while (i < persona_list.size) {
      if (persona_list[i].store.type_id == "key-file")
	persona_list.remove_at (i);
      else
	i++;
    }
    persona_list.add_all (contact.individual.personas);
    var fake_persona = FakePersona.maybe_create_for (contact);
    if (fake_persona != null)
      persona_list.add (fake_persona);
    persona_list.sort (Contact.compare_persona_by_store);

    if (persona == null)
      persona = persona_list[0];

    PersonaButton button = null;
    if (persona_list.size > 1) {
      foreach (var p in persona_list) {

	button = new PersonaButton (button, p as AvatarDetails, 48);
	personas.add (button);

	if (p == persona)
	  button.set_active (true);

	button.toggled.connect ( (a_button) => {
	    if (a_button.get_active ())
	      update_edit_details (image_frame, p, false);
	  });
      }
    }

    update_edit_details (image_frame, persona, new_contact);

    g.attach (personas,  0, 3, 1, 1);
    fields_grid.show_all ();
  }

  private void display_contact (Contact contact) {
    set_display_mode (DisplayMode.DETAILS);
    set_has_notes (!contact.individual.notes.is_empty);
    display_card (contact);

    var emails = Contact.sort_fields<EmailFieldDetails>(contact.individual.email_addresses);
    foreach (var email in emails) {
      var type = TypeSet.general.format_type (email);
      layout.add_label_detail (type, email.value);
      var button = layout.add_button ("mail-unread-symbolic");
      var email_addr = email.value;
      button.clicked.connect ( () => {
	  Utils.compose_mail (email_addr);
	});
    }

    var ims = contact.individual.im_addresses;
    var im_keys = ims.get_keys ();
    if (!im_keys.is_empty) {
      foreach (var protocol in im_keys) {
	foreach (var id in ims[protocol]) {
	  layout.add_label_detail (_("Chat"), contact.format_im_name (protocol, id.value));
	  Button? button = null;
	  var presence = contact.create_presence_widget (protocol, id.value);
	  if (presence != null) {
	    button = layout.add_button (null);
	    button.add (presence);
	  }

	  if (button != null) {
	    button.clicked.connect ( () => {
		Utils.start_chat (contact, protocol, id.value);
	      });
	  }
	}
      }
    }

    var phone_numbers = Contact.sort_fields<PhoneFieldDetails>(contact.individual.phone_numbers);
    foreach (var p in phone_numbers) {
      var phone = p as PhoneFieldDetails;
      var type = TypeSet.phone.format_type (phone);
      layout.add_label_detail (type, phone.value);
    }

    var postals = contact.individual.postal_addresses;
    if (!postals.is_empty) {
      foreach (var addr in postals) {
	var type = TypeSet.general.format_type (addr);
	string[] strs = Contact.format_address (addr.value);
	layout.add_label (type);
	if (strs.length > 0) {
	  foreach (var s in strs)
	    layout.add_detail (s);
	}
	var button = layout.add_button ("edit-copy-symbolic");
	button.clicked.connect ( () => {
	    string addr_s = "";
	    foreach (var s in Contact.format_address (addr.value)) {
	      addr_s += s + "\n";
	    }
	    Clipboard.get_for_display (button.get_screen().get_display(), Gdk.SELECTION_CLIPBOARD).set_text (addr_s, -1);
	    var notification = new Notify.Notification (_("Address copied to clipboard"), null, "edit-copy");
	    notification.set_timeout (3000);
	    notification.set_urgency (Notify.Urgency.CRITICAL);
	    try {
	      notification.show ();
	      Timeout.add (3000, () => {
		  try {
		    notification.close ();
		  }
		  catch (Error e) {
		  }
		  return false;
		});
	    }
	    catch (Error e) {
	    }
	  });
      }
    }

    var urls = contact.individual.urls;
    if (!urls.is_empty) {
      layout.add_label ("Links");
      foreach (var url_details in urls) {
	layout.add_link (url_details.value, contact.format_uri_link_text (url_details));
      }
    }

    fields_grid.show_all ();
  }

  private void set_has_notes (bool has_notes) {
    this.has_notes = has_notes;
    notes_dot.queue_draw ();
  }

  private void selected_contact_changed () {
    if (display_mode == DisplayMode.DETAILS) {
      display_contact (selected_contact);
    }
  }

  private void set_display_mode (DisplayMode mode) {
    layout.reset (true);

    if (display_mode == mode)
      return;

    display_mode = mode;
    if (mode == DisplayMode.EMPTY || mode == DisplayMode.DETAILS) {
      normal_buttons.show ();
      editing_buttons.hide ();
      normal_buttons.set_sensitive (mode != DisplayMode.EMPTY);
    } else {
      normal_buttons.hide ();
      editing_buttons.show ();
    }
  }

  public void new_contact () {
    var details = new HashTable<string, Value?> (str_hash, str_equal);
    contacts_store.aggregator.primary_store.add_persona_from_details.begin (details, (obj, res) => {
	var store = obj as PersonaStore;
	Persona? persona = null;
	try {
	  persona = store.add_persona_from_details.end (res);
	} catch (Error e) {
	  var dialog = new MessageDialog (this.get_toplevel () as Window,
					  DialogFlags.DESTROY_WITH_PARENT,
					  MessageType.ERROR,
					  ButtonsType.OK,
					  _("Unable to create new contacts: %s\n"), e.message);
	  dialog.show ();
	  return;
	}

	var contact = contacts_store.find_contact_with_persona (persona);
	if (contact == null) {
	  var dialog = new MessageDialog (this.get_toplevel () as Window,
					  DialogFlags.DESTROY_WITH_PARENT,
					  MessageType.ERROR,
					  ButtonsType.OK,
					  _("Unable to find newly created contact\n"));
	  dialog.show ();
	  return;
	}

	show_contact (contact);
	display_edit (contact, persona, true);
      });

  }

  public void show_contact (Contact? new_contact, bool edit=false) {
    this.save_data (); // Ensure all edit data saved

    if (selected_contact != null)
      selected_contact.changed.disconnect (selected_contact_changed);

    selected_contact = new_contact;
    editing_persona = null;
    set_display_mode (DisplayMode.EMPTY);
    set_has_notes (false);

    if (selected_contact != null) {
	display_contact (selected_contact);
	selected_contact.changed.connect (selected_contact_changed);
    }
  }

  public ContactPane (Store contacts_store) {
    this.contacts_store = contacts_store;

    get_style_context ().add_class ("contact-pane");

    var grid = new Grid ();
    grid.set_border_width (10);
    this.add (grid);

    var fields_scrolled = new ScrolledWindow (null, null);
    fields_scrolled.set_hexpand (true);
    fields_scrolled.set_vexpand (true);
    fields_scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

    fields_grid = new Grid ();
    fields_grid.set_column_spacing (3);
    fields_grid.set_orientation (Orientation.VERTICAL);
    fields_scrolled.add_with_viewport (fields_grid);
    fields_scrolled.get_child().get_style_context ().add_class ("contact-pane");

    layout = new DetailsLayout (fields_grid);

    grid.attach (fields_scrolled, 0, 1, 1, 1);

    var bbox = new ButtonBox (Orientation.HORIZONTAL);
    normal_buttons = bbox;
    bbox.set_spacing (5);
    bbox.set_margin_top (8);
    bbox.set_layout (ButtonBoxStyle.START);
    grid.attach (bbox, 0, 2, 1, 1);

    var notes_button = new Button ();
    var notes_grid = new Grid ();
    var label = new Label(_("Notes"));
    label.set_hexpand (true);
    // We create an empty widget the same size as the dot in order
    // to make the label center correctly
    var a = new DrawingArea();
    a.set_size_request (6, -1);
    a.set_has_window (false);
    notes_grid.add (a);
    notes_grid.add (label);
    notes_dot = new DrawingArea();
    notes_dot.set_has_window (false);
    notes_dot.set_size_request (6, -1);
    notes_dot.draw.connect ( (widget, cr) => {
	if (has_notes) {
	  cr.arc (3, 3 + 2, 3, 0, 2 * Math.PI);
	  Gdk.RGBA color;
	  color = widget.get_style_context ().get_color (0);
	  Gdk.cairo_set_source_rgba (cr, color);
	  cr.fill ();
	}
	return true;
      });
    notes_grid.add (notes_dot);
    notes_button.add (notes_grid);

    notes_button.clicked.connect ( (button) => {
	display_notes ();
      });

    bbox.pack_start (notes_button, false, false, 0);

    var button = new Button.with_label(_("Edit"));
    bbox.pack_start (button, false, false, 0);

    button.clicked.connect ( (button) => {
	display_edit (selected_contact, null);
      });

    MenuButton menu_button = new MenuButton (_("More"));
    bbox.pack_start (menu_button, false, false, 0);

    bbox.show_all ();
    bbox.set_no_show_all (true);

    bbox = new ButtonBox (Orientation.HORIZONTAL);
    editing_buttons = bbox;
    bbox.set_spacing (5);
    bbox.set_margin_top (8);
    bbox.set_layout (ButtonBoxStyle.END);
    grid.attach (bbox, 0, 3, 1, 1);

    button = new Button.from_stock(Stock.CLOSE);
    bbox.pack_start (button, false, false, 0);

    button.clicked.connect ( (button) => {
	this.save_data (); // Ensure all edit data saved
	display_contact (selected_contact);
      });

    var menu = new Menu ();
    Utils.add_menu_item (menu,_("Add/Remove Linked Contacts...")).activate.connect (link_contact);
    Utils.add_menu_item (menu,_("Send..."));
    Utils.add_menu_item (menu,_("Delete"));

    menu_button.set_menu (menu);

    bbox.show_all ();
    bbox.set_no_show_all (true);

    grid.show_all ();

    set_display_mode (DisplayMode.EMPTY);
    set_has_notes (false);
  }

  void link_contact () {
    var dialog = new LinkDialog (selected_contact);
    dialog.show_all ();
  }
}
