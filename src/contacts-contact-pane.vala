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

class DetailsLayout : Object {
  public DetailsLayout (Grid fields_grid) {
    this.fields_grid = fields_grid;
    label_size_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
  }

  Grid fields_grid;
  SizeGroup label_size_group;

  private bool expands;
  public Grid? current_row;
  Widget? last_label;

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
    current_row = grid;
    expands = false;
    last_label = null;
    grid.set_row_spacing (8);
    grid.set_orientation (Orientation.HORIZONTAL);
    fields_grid.add (grid);
  }

  public void add_widget_label (Widget w) {
    new_row ();

    label_size_group.add_widget (w);
    current_row.add (w);
  }

  public void add_label (string label) {
    var l = new Label (label);
    l.get_style_context ().add_class ("dim-label");
    l.set_alignment (1, 0.5f);

    add_widget_label (l);
  }

  public void attach_detail (Widget widget) {
    if (last_label != null)
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

    get_style_context ().add_class ("contact-frame");
    set_shadow_type (ShadowType.OUT);
  }

  public void set_image (AvatarDetails? details) {
    pixbuf = null;
    if (details != null &&
	details.avatar != null &&
	details.avatar.get_path () != null) {
      try {
	pixbuf = new Gdk.Pixbuf.from_file_at_scale (details.avatar.get_path (), size, size, true);
      }
      catch {
      }
    }

    if (pixbuf == null) {
      pixbuf = Contact.draw_fallback_avatar (size);
    }
  }

  public void set_text (string? text_, int text_height_) {
    text = text_;
    text_height = text_height_;
    layout = null;
    if (text != null) {
      layout = create_pango_layout (text);
      layout.set_width (size);
      layout.set_height (text_height);
      layout.set_alignment (Pango.Alignment.CENTER);
    }
  }

  public override bool draw (Cairo.Context cr) {
    cr.save ();

    if (pixbuf != null) {
      Gdk.cairo_set_source_pixbuf (cr, pixbuf, 2, 2);
      cr.paint();
    }

    if (layout != null) {
      cr.set_source_rgba (0, 0, 0, 0.5);
      cr.rectangle (2, 2 + size - text_height, size, text_height);
      cr.fill ();

      cr.set_source_rgb (1.0, 1.0, 1.0);
      Gtk.render_layout (get_style_context (), cr,
			 size / 2, size - text_height,
			 layout);
    }
    cr.restore ();

    base.draw (cr);
    return true;
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

  HashSet<FieldDetails> editing_emails;
  HashSet<FieldDetails> editing_phones;
  HashSet<FieldDetails> editing_urls;

  const int PROFILE_SIZE = 96;
  const int LABEL_HEIGHT = 20;

  private signal void save_data ();

  private Widget create_image (AvatarDetails? details, int size) {
    var image = new Image ();
    image.set_size_request (size, size);

    Gdk.Pixbuf pixbuf = null;
    if (details != null &&
	details.avatar != null &&
	details.avatar.get_path () != null) {
      try {
	pixbuf = new Gdk.Pixbuf.from_file_at_scale (details.avatar.get_path (), size, size, true);
      }
      catch {
      }
    }

    if (pixbuf == null) {
      pixbuf = Contact.draw_fallback_avatar (size);
    }

    if (pixbuf != null) {
      image.set_from_pixbuf (pixbuf);
    }

    return image;
  }

  private void update_edit_detail_type (Set<FieldDetails> detail_set,
					TypeCombo combo,
					string property_name) {
    FieldDetails? old_detail = null;
    foreach (var detail in detail_set) {
      if (detail.get_data<TypeCombo> ("combo") == combo) {
	old_detail = detail;
	break;
      }
    }
    assert (old_detail != null);

    var new_detail = combo.update_details (old_detail);
    new_detail.set_data ("entry", old_detail.get_data<Entry> ("entry"));
    new_detail.set_data ("combo", old_detail.get_data<TypeCombo> ("combo"));

    detail_set.remove (old_detail);
    detail_set.add (new_detail);

    editing_persona.set (property_name, detail_set);
  }

  private void add_detail_combo (TypeSet type_set,
				 Set<FieldDetails> detail_set,
				 FieldDetails detail,
				 string property_name) {
    var combo = new TypeCombo (type_set);
    combo.set_halign (Align.FILL);
    combo.set_hexpand (false);
    combo.set_active (detail);
    layout.add_widget_label (combo);
    detail.set_data ("combo", combo);

    combo.changed.connect ( () => {
	update_edit_detail_type (detail_set, combo, property_name);
      });
  }

  private void update_edit_detail_value (Set<FieldDetails> detail_set,
					 Entry entry,
					 string property_name) {
    FieldDetails? old_detail = null;
    foreach (var detail in detail_set) {
      if (detail.get_data<Entry> ("entry") == entry) {
	old_detail = detail;
	break;
      }
    }
    assert (old_detail != null);

    if (old_detail.value != entry.get_text ()) {
      var new_detail = new FieldDetails (entry.get_text ());
      new_detail.parameters = old_detail.parameters;
      new_detail.set_data ("entry", old_detail.get_data<Entry> ("entry"));
      new_detail.set_data ("combo", old_detail.get_data<TypeCombo> ("combo"));

      detail_set.remove (old_detail);
      detail_set.add (new_detail);

      editing_persona.set (property_name, detail_set);
    }
  }

  private void add_detail_entry (Set<FieldDetails> detail_set,
				 FieldDetails detail,
				 string property_name) {
    var entry = layout.add_entry (detail.value);
    detail.set_data ("entry", entry);

    entry.focus_out_event.connect ( (ev) => {
	update_edit_detail_value (detail_set, entry, property_name);
	return false;
      });
  }

  private void add_detail_remove (Set<FieldDetails> detail_set,
				  FieldDetails detail,
				  string property_name,
				  bool at_top = true) {
    var remove_button = layout.add_remove (at_top);
    var row = layout.current_row;

    remove_button.clicked.connect ( () => {
	detail_set.remove (detail);
	editing_persona.set (property_name, detail_set);
	row.destroy ();
      });
  }

  private void add_detail_editor (TypeSet type_set,
				  Set<FieldDetails> detail_set,
				  FieldDetails detail,
				  string property_name) {
    detail_set.add (detail);
    add_detail_combo (type_set, detail_set, detail, property_name);
    add_detail_entry (detail_set, detail, property_name);
    add_detail_remove (detail_set, detail, property_name);
  }

  private void update_edit_details (ContactFrame image_frame, Persona persona) {
    layout.reset (false);
    image_frame.set_image (persona as AvatarDetails);
    image_frame.set_text (persona.store.display_name, LABEL_HEIGHT);

    editing_emails = new HashSet<FieldDetails>();
    editing_phones = new HashSet<FieldDetails>();
    editing_urls = new HashSet<FieldDetails>();

    var email_details = persona as EmailDetails;
    if (email_details != null) {
      var emails = email_details.email_addresses;
      if (!emails.is_empty) {
	foreach (var email in Contact.sort_fields (emails)) {
	  add_detail_editor (TypeSet.general,
			     editing_emails, email,
			     "email_addresses");
	}
      }
    }

    var im_details = persona as ImDetails;
    if (im_details != null) {
      var ims = im_details.im_addresses;
      var im_keys = ims.get_keys ();
      if (!im_keys.is_empty) {
	foreach (var protocol in im_keys) {
	  foreach (var id in ims[protocol]) {
	    layout.add_label_detail (_("Chat"), protocol + "/" + id);
	    layout.add_remove ();
	  }
	}
      }
    }


    var phone_details = persona as PhoneDetails;
    if (phone_details != null) {
      var phone_numbers = phone_details.phone_numbers;
      if (!phone_numbers.is_empty) {
	foreach (var p in Contact.sort_fields (phone_numbers)) {
	  add_detail_editor (TypeSet.phone,
			     editing_phones, p,
			     "phone_numbers");
	}
      }
    }

    var postal_details = persona as PostalAddressDetails;
    if (postal_details != null) {
      var postals = postal_details.postal_addresses;
      if (!postals.is_empty) {
	foreach (var addr in postals) {
	  var type = "";
	  var types = addr.types;
	  if (types != null) {
	    var i = types.iterator();
	    if (i.next())
	      type = type + i.get();
	  }
	  string[] strs = Contact.format_address (addr);
	  layout.add_label (type);
	  foreach (var s in strs) {
	    layout.add_detail (s);
	  }
	  layout.add_remove ();
	}
      }
    }

    var urls_details = persona as UrlDetails;
    if (urls_details != null) {
      var urls = urls_details.urls;
      if (!urls.is_empty) {
	layout.add_label ("Links");
	foreach (var url_details in urls) {
	  editing_urls.add (url_details);
	  add_detail_entry (editing_urls,
			    url_details,
			    "urls");
	  add_detail_remove (editing_urls,
			     url_details,
			     "urls",
			     false);
	}
      }
    }

    fields_grid.show_all ();
  }

  private void display_card (Contact contact) {
    var image_frame = new ContactFrame (PROFILE_SIZE);
    image_frame.set_image (contact.individual);
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

      var notes = new HashSet<Note> ();
      foreach (var view in widgets.get (persona)) {
	if (view.get_buffer ().get_modified ())
	  modified = true;
	string? uid = view.get_data<string?> ("uid");
	TextIter start, end;
	view.get_buffer ().get_start_iter (out start);
	view.get_buffer ().get_end_iter (out end);
	var text = view.get_buffer ().get_text (start, end, true);
	if (text.length > 0) {
	  var note = new Note (text, uid);
	  notes.add (note);
	}
      }

      if (modified) {
	if (persona == null) {
	  selected_contact.ensure_writable_persona.begin ( (obj, result) => {
	      var p = selected_contact.ensure_writable_persona.end (result);
	      if (p is NoteDetails)
		(p as NoteDetails).notes = notes;
	      else
		warning ("Writable store doesn't support notes");
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

  private void update_note (TextView text, Note note) {
    text.get_buffer ().set_text (note.content);
    text.get_buffer ().set_modified (false);
    text.set_data<string?> ("uid", note.uid);
  }

  private void display_notes () {
    set_display_mode (DisplayMode.NOTES);
    display_card (selected_contact);

    var widgets = new HashMultiMap<Persona?, TextView>();
    var main_text = add_note ();

    Persona? writable_persona = selected_contact.find_writable_persona ();
    if (writable_persona == null || writable_persona is NoteDetails)
      widgets.set (writable_persona, main_text);
    else
      warning ("Writable store doesn't support notes");

    bool primary_note_seen = false;

    foreach (var persona in selected_contact.individual.personas) {
      var notes = persona as NoteDetails;
      if (notes == null)
	continue;
      foreach (var note in notes.notes) {
	if (persona == writable_persona && !primary_note_seen) {
	  primary_note_seen = true;
	  update_note (main_text, note);
	} else if (persona.store.is_writeable) {
	  var text = add_note ();
	  update_note (text, note);
	  widgets.set (persona, text);
	} else {
	  var label = new Label (note.content);
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

  private void display_edit (Contact contact, Persona persona) {
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
    e.set_text (contact.display_name);
    e.set_hexpand (true);
    e.set_halign (Align.START);
    e.set_valign (Align.START);
    g.attach (e,  0, 0, 1, 1);

    var personas = new Grid ();
    personas.set_row_spacing (4);
    personas.set_halign (Align.START);
    personas.set_valign (Align.END);
    personas.set_vexpand (true);

    RadioButton button = null;
    foreach (var p in contact.individual.personas) {

      button = new RadioButton.from_widget (button);
      button.get_style_context ().add_class ("contact-button");
      button.set_can_default (false);
      var image = create_image (p as AvatarDetails, 48);
      button.add (image);
      button.set_mode (false);
      personas.add (button);

      if (p == persona) {
	button.set_active (true);
      }
      button.toggled.connect ( (a_button) => {
	  if (a_button.get_active ())
	    update_edit_details (image_frame, p);
	});
    }

    update_edit_details (image_frame, persona);

    g.attach (personas,  0, 3, 1, 1);
    fields_grid.show_all ();
  }

  private void display_contact (Contact contact) {
    set_display_mode (DisplayMode.DETAILS);
    set_has_notes (!contact.individual.notes.is_empty);
    display_card (contact);

    var emails = contact.individual.email_addresses;
    if (!emails.is_empty) {
      foreach (var email in Contact.sort_fields (emails)) {
	var type = TypeSet.general.format_type (email);
	layout.add_label_detail (type, email.value);
	var button = layout.add_button ("mail-unread-symbolic");
	var email_addr = email.value;
	button.clicked.connect ( () => {
	    Utils.compose_mail (email_addr);
	  });
      }
    }

    var ims = contact.individual.im_addresses;
    var im_keys = ims.get_keys ();
    if (!im_keys.is_empty) {
      foreach (var protocol in im_keys) {
	foreach (var id in ims[protocol]) {
	  layout.add_label_detail (_("Chat"), contact.format_im_name (protocol, id));
	  Button? button = null;
	  var presence = contact.create_presence_widget (protocol, id);
	  if (presence != null) {
	    button = layout.add_button (null);
	    button.add (presence);
	  }

	  if (button != null) {
	    button.clicked.connect ( () => {
		Utils.start_chat (contact, protocol, id);
	      });
	  }
	}
      }
    }

    var phone_numbers = contact.individual.phone_numbers;
    if (!phone_numbers.is_empty) {
      foreach (var p in Contact.sort_fields (phone_numbers)) {
	var type = TypeSet.phone.format_type (p);
	layout.add_label_detail (type, p.value);
      }
    }

    var postals = contact.individual.postal_addresses;
    if (!postals.is_empty) {
      foreach (var addr in postals) {
	var type = "";
	var types = addr.types;
	if (types != null) {
	  var i = types.iterator();
	  if (i.next())
	    type = type + i.get();
	}
	string[] strs = Contact.format_address (addr);
	layout.add_label (type);
	if (strs.length > 0) {
	  foreach (var s in strs)
	    layout.add_detail (s);
	}
	var button = layout.add_button ("edit-copy-symbolic");
	button.clicked.connect ( () => {
	    string addr_s = "";
	    foreach (var s in Contact.format_address (addr)) {
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

  public void show_contact (Contact? new_contact) {
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
	editing_persona = null;
	var i = selected_contact.individual.personas.iterator();
	if (i.next())
	  editing_persona = i.get();

	display_edit (selected_contact, editing_persona);
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
    var mi = new MenuItem.with_label (_("Add/Remove Linked Contacts..."));
    menu.append (mi);
    mi.show ();
    mi = new MenuItem.with_label (_("Send..."));
    menu.append (mi);
    mi.show ();
    mi = new MenuItem.with_label (_("Delete"));
    menu.append (mi);
    mi.show ();

    menu_button.set_menu (menu);

    bbox.show_all ();
    bbox.set_no_show_all (true);

    grid.show_all ();

    set_display_mode (DisplayMode.EMPTY);
    set_has_notes (false);
  }
}
