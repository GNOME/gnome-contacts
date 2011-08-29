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
  public class SharedState {
    public SizeGroup label_size_group;
    public SharedState () {
      label_size_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
    }
  }

  public DetailsLayout (SharedState s) {
    shared_state = s;
    grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_column_spacing (3);
  }

  SharedState shared_state;
  public Grid grid;

  private bool expands;
  public Grid? current_row;
  Widget? last_label;
  Box? detail_box;

  public void reset () {
    foreach (var w in grid.get_children ()) {
      w.destroy ();
    }
    current_row = null;
    last_label = null;
    detail_box = null;
  }

  void new_row () {
    var row = new Grid ();
    expands = false;
    last_label = null;
    row.set_row_spacing (9);
    row.set_column_spacing (3);
    row.set_orientation (Orientation.HORIZONTAL);
    current_row = row;
    grid.add (row);
  }

  public void add_widget_label (Widget w) {
    new_row ();

    shared_state.label_size_group.add_widget (w);
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
}

public class Contacts.ContactFrame : Frame {
  private int size;
  private string? text;
  private Gdk.Pixbuf? pixbuf;
  private Pango.Layout? layout;
  private int text_height;
  private bool popup_in_progress;
  private Menu? menu;

  private void menu_position (Menu menu, out int x, out int y, out bool push_in) {
    Allocation allocation;
    get_allocation (out allocation);

    int sx = 0;
    int sy = 0;

    if (!get_has_window ()) {
      sx += allocation.x;
      sy += allocation.y;
    }

    get_window ().get_root_coords (sx, sy, out sx, out sy);

    Requisition menu_req;
    Gdk.Rectangle monitor;

    menu.get_preferred_size (null, out menu_req);

    if (get_direction () == TextDirection.LTR)
      x = sx + 2;
    else
      x = sx + allocation.width - menu_req.width - 2;
    y = sy - 2;

    var window = get_window ();
    var screen = get_screen ();
    var monitor_num = screen.get_monitor_at_window (window);
    if (monitor_num < 0)
      monitor_num = 0;
    screen.get_monitor_geometry (monitor_num, out monitor);

    if (x < monitor.x)
      x = monitor.x;
    else if (x + menu_req.width > monitor.x + monitor.width)
      x = monitor.x + monitor.width - menu_req.width;

    if (monitor.y + monitor.height - y - allocation.height >= menu_req.height)
      y += allocation.height;
    else if (y - monitor.y >= menu_req.height)
      y -= menu_req.height;
    else if (monitor.y + monitor.height - y - allocation.height > y - monitor.y)
      y += allocation.height;
    else
      y -= menu_req.height;

    menu.set_monitor (monitor_num);

    Window? toplevel = menu.get_parent() as Window;
    if (toplevel != null && !toplevel.get_visible())
      toplevel.set_type_hint (Gdk.WindowTypeHint.DROPDOWN_MENU);

    push_in = false;
  }

  public ContactFrame (int size, Menu? menu = null) {
    this.size = size;

    var image = new Image ();
    image.set_size_request (size, size);

    this.menu = menu;
    if (menu != null) {
      var button = new ToggleButton ();
      button.set_focus_on_click (false);
      button.get_style_context ().add_class ("contact-frame-button");
      button.add (image);
      button.set_mode (false);
      this.add (button);

      button.toggled.connect ( () => {
	  if (button.get_active ()) {
	    if (!popup_in_progress) {
	      menu.popup (null, null, menu_position, 1, Gtk.get_current_event_time ());
	    }
	  } else {
	    menu.popdown ();
	  }
	});

      button.button_press_event.connect ( (event) => {
	  var ewidget = Gtk.get_event_widget ((Gdk.Event)(&event));

	  if (ewidget != button ||
	      button.get_active ())
	    return false;

	  menu.popup (null, null, menu_position, 1, Gtk.get_current_event_time ());
	  button.set_active (true);
	  popup_in_progress = true;
	  return true;
	});
      button.button_release_event.connect ( (event) => {
	  bool popup_in_progress_saved = popup_in_progress;
	  popup_in_progress = false;

	  var ewidget = Gtk.get_event_widget ((Gdk.Event)(&event));

	  if (ewidget == button &&
	      !popup_in_progress_saved &&
	      button.get_active ()) {
	    menu.popdown ();
	    return true;
	  }
	  if (ewidget != button)    {
	    menu.popdown ();
	    return true;
	  }
	  return false;
	});

      menu.show.connect ( (menu) => {
	  popup_in_progress = true;
	  button.set_active (true);
	  popup_in_progress = false;
	});
      menu.hide.connect ( (menu) => {
	  button.set_active (false);
	});
      menu.attach_to_widget (button, (menu) => {
	});
    } else {
      this.add (image);
    }

    image.show ();
    image.draw.connect (draw_image);

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
    queue_draw ();
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
    queue_draw ();
  }

  public bool draw_image (Cairo.Context cr) {
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


public class Contacts.ContactPane : Grid {
  private enum DisplayMode {
    INITIAL,
    EMPTY,
    DETAILS,
    NOTES,
    EDIT
  }
  private Store contacts_store;
  private Contact? selected_contact;
  private DisplayMode display_mode;
  private Grid card_grid;
  private Grid fields_grid;
  private Grid button_grid;

  /* Stuff used only in edit mode */
  private ContactFrame edit_image_frame;
  private Grid edit_persona_grid;
  private Persona? editing_persona;
  private Persona? editing_persona_primary;

  private bool has_notes;
  private Widget notes_dot;
  private Widget empty_widget;
  private EventBox pane;
  private ButtonBox normal_buttons;
  private ButtonBox editing_buttons;
  private DetailsLayout.SharedState layout_state;
  private DetailsLayout card_layout;
  private DetailsLayout fields_layout;
  private DetailsLayout button_layout;

  HashSet<EmailFieldDetails> editing_emails;
  HashSet<PhoneFieldDetails> editing_phones;
  HashSet<UrlFieldDetails> editing_urls;
  HashSet<PostalAddressFieldDetails> editing_postals;

  const int PROFILE_SIZE = 96;
  const int LABEL_HEIGHT = 20;

  private signal void save_data ();

  private async Persona? set_persona_property (Persona persona,
					       string property_name,
					       Value value) throws GLib.Error {
    if (persona is FakePersona) {
      var fake = persona as FakePersona;
      return yield fake.make_real_and_set (property_name, value);
    } else {
      persona.set_data ("contacts-unedited", true);
      persona.set_property (property_name, value);
      return null;
    }
  }

  private void update_detail_property (string property_name,
				       Set<AbstractFieldDetails> detail_set) {
    var editing_backup = editing_persona;
    var value = Value (detail_set.get_type ());
    value.set_object (detail_set);
    set_persona_property.begin (editing_persona, property_name, value, (obj, result) => {
	  try {
	    var p = set_persona_property.end (result);
	    if (p != null &&
		display_mode == DisplayMode.EDIT &&
		editing_persona == editing_backup) {
	      update_persona_buttons (selected_contact, p);
	      editing_persona = p;
	      editing_persona_primary = p;
	    }
	  } catch (Error e) {
	    warning ("Unable to create writeable persona: %s", e.message);
	  }
      });
  }

  private void update_edit_detail_type (Set<AbstractFieldDetails> detail_set,
					AbstractFieldDetails detail,
					TypeCombo combo,
					string property_name) {
    combo.update_details (detail);
    update_detail_property (property_name, detail_set);
  }

  private void add_detail_combo (DetailsLayout layout,
				 TypeSet type_set,
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

  private Entry add_detail_entry (DetailsLayout layout,
				  Set<AbstractFieldDetails> detail_set,
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

  private Entry add_detail_postal_entry (DetailsLayout layout,
					 Set<PostalAddressFieldDetails> detail_set,
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

  private Button add_detail_remove (DetailsLayout layout,
				    Set<AbstractFieldDetails> detail_set,
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

  private void add_detail_editor (DetailsLayout layout,
				  TypeSet type_set,
				  Set<AbstractFieldDetails> detail_set,
				  AbstractFieldDetails<string> detail,
				  string property_name,
				  string? placeholder_text) {
    detail_set.add (detail);
    add_detail_combo (layout, type_set, detail_set, detail, property_name);
    add_detail_entry (layout, detail_set, detail, property_name, placeholder_text);
    add_detail_remove (layout, detail_set, detail, property_name);
  }

  private void add_detail_editor_no_type (DetailsLayout layout,
					  Set<AbstractFieldDetails> detail_set,
					   AbstractFieldDetails<string> detail,
					   string property_name,
					   string? placeholder_text) {
    detail_set.add (detail);
    add_detail_entry (layout, detail_set, detail, property_name, placeholder_text);
    add_detail_remove (layout, detail_set, detail, property_name, false);
  }

  private void add_email_editor (DetailsLayout layout,
				 Set<AbstractFieldDetails> detail_set,
				 EmailFieldDetails? email) {
    add_detail_editor (layout,
		       TypeSet.general,
		       detail_set,
		       email != null ? new EmailFieldDetails (email.value, email.parameters) : new EmailFieldDetails(""),
		       "email-addresses",
		       _("Enter email address"));
  }

  private void add_phone_editor (DetailsLayout layout,
				 Set<AbstractFieldDetails> detail_set,
				 PhoneFieldDetails? p) {
    add_detail_editor (layout,
		       TypeSet.phone,
		       detail_set,
		       p != null ? new PhoneFieldDetails (p.value, p.parameters) : new PhoneFieldDetails(""),
		       "phone-numbers",
		       _("Enter phone number"));
  }

  private void add_url_editor (DetailsLayout layout,
			       Set<AbstractFieldDetails> detail_set,
			       UrlFieldDetails? url) {
    if (layout.grid.get_children ().length () == 0)
      layout.add_label ("Links");

    add_detail_editor_no_type (layout,
			       detail_set,
			       url != null ? new UrlFieldDetails (url.value, url.parameters) : new UrlFieldDetails (""),
			       "urls",
			       _("Enter link"));
  }

  private void add_postal_editor (DetailsLayout layout,
				  Set<PostalAddressFieldDetails> detail_set,
				  PostalAddressFieldDetails detail) {
    string[] props = {"street", "extension", "locality", "region", "postal_code", "po_box", "country"};
    string[] nice = {_("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

    detail_set.add (detail);
    add_detail_combo (layout, TypeSet.general, detail_set, detail, "postal_addresses");

    layout.begin_detail_box ();
    for (int i = 0; i < props.length; i++) {
      add_detail_postal_entry (layout,
			       detail_set,
			       detail,
			       props[i],
			       "postal-addresses",
			       nice[i]);
    }
    layout.end_detail_box ();
    var button = add_detail_remove (layout, detail_set, detail, "postal-addresses");
    button.set_valign (Align.START);
  }

  private void update_edit_details (Persona persona, bool new_contact) {
    editing_persona = persona;
    fields_layout.reset ();
    button_layout.reset ();

    edit_image_frame.set_image (persona as AvatarDetails);
    edit_image_frame.set_text (Contact.format_persona_store_name (persona.store), LABEL_HEIGHT);

    editing_emails = new HashSet<EmailFieldDetails>();
    editing_phones = new HashSet<PhoneFieldDetails>();
    editing_urls = new HashSet<UrlFieldDetails>();
    editing_postals = new HashSet<PostalAddressFieldDetails>();

    var email_layout = new DetailsLayout (layout_state);
    fields_grid.add (email_layout.grid);

    var email_details = persona as EmailDetails;
    if (email_details != null) {
      var emails = Contact.sort_fields<EmailFieldDetails>(email_details.email_addresses);
      foreach (var email in emails) {
	add_email_editor (email_layout,
			  editing_emails, email);
      }
    }

    if (new_contact)
      add_email_editor (email_layout,
			editing_emails, null);

    var im_layout = new DetailsLayout (layout_state);
    fields_grid.add (im_layout.grid);

    var im_details = persona as ImDetails;
    if (im_details != null) {
      var ims = im_details.im_addresses;
      var im_keys = ims.get_keys ();
      foreach (var protocol in im_keys) {
	foreach (var id in ims[protocol]) {
	  var im_persona = selected_contact.find_im_persona (protocol, id.value);
	  if (im_persona != null && im_persona != persona)
	    continue;
	  im_layout.add_label_detail (_("Chat"), protocol + "/" + id.value);
	  var button = im_layout.add_remove ();
	  button.set_sensitive (false);
	}
      }
    }

    var phone_layout = new DetailsLayout (layout_state);
    fields_grid.add (phone_layout.grid);

    var phone_details = persona as PhoneDetails;
    if (phone_details != null) {
      var phone_numbers = Contact.sort_fields<PhoneFieldDetails>(phone_details.phone_numbers);
      foreach (var p in phone_numbers) {
	add_phone_editor (phone_layout,
			  editing_phones, p);
      }
    }

    if (new_contact)
      add_phone_editor (phone_layout,
			editing_phones, null);

    var postal_layout = new DetailsLayout (layout_state);
    fields_grid.add (postal_layout.grid);

    var postal_details = persona as PostalAddressDetails;
    if (postal_details != null) {
      var postals = postal_details.postal_addresses;
      foreach (var _addr in postals) {
	add_postal_editor (postal_layout,
			   editing_postals,
			   new PostalAddressFieldDetails(_addr.value, _addr.parameters));
      }
    }

    var url_layout = new DetailsLayout (layout_state);
    fields_grid.add (url_layout.grid);

    var urls_details = persona as UrlDetails;
    if (urls_details != null) {
      var urls = urls_details.urls;
      foreach (var url_details in urls) {
	add_url_editor (url_layout,
			editing_urls,
			url_details);
      }
    }

    if (Contact.persona_has_writable_property (persona, "email-addresses") ||
	Contact.persona_has_writable_property (persona, "phone-numbers") ||
	Contact.persona_has_writable_property (persona, "postal-addresses") ||
	Contact.persona_has_writable_property (persona, "urls")) {
      button_layout.add_label ("");
      var menu_button = new MenuButton (_("Add detail"));
      menu_button.set_hexpand (false);
      menu_button.set_margin_top (12);

      var menu = new Menu ();
      if (Contact.persona_has_writable_property (persona, "email-addresses")) {
	Utils.add_menu_item (menu, _("Email")).activate.connect ( () => {
	    add_email_editor (email_layout,
			      editing_emails, null);
	    email_layout.grid.show_all ();
	  });
      }
      if (Contact.persona_has_writable_property (persona, "phone-numbers")) {
	Utils.add_menu_item (menu, _("Phone number")).activate.connect ( () => {
	    add_phone_editor (phone_layout,
			      editing_phones, null);
	    phone_layout.grid.show_all ();
	  });
      }
      if (Contact.persona_has_writable_property (persona, "postal-addresses")) {
	Utils.add_menu_item (menu, _("Postal Address")).activate.connect ( () => {
	    add_postal_editor (postal_layout,
			       editing_postals,
			       new PostalAddressFieldDetails(new PostalAddress (null, null, null, null, null, null, null, null, null), null));
	    postal_layout.grid.show_all ();
	  });
      }
      if (Contact.persona_has_writable_property (persona, "urls")) {
	Utils.add_menu_item (menu,_("Link")).activate.connect ( () => {
	    add_url_editor (url_layout,
			    editing_urls,
			    null);
	    url_layout.grid.show_all ();
	  });
      }

      menu_button.set_menu (menu);

      button_layout.attach_detail (menu_button);
    }

    card_grid.show_all ();
    fields_grid.show_all ();
    button_grid.show_all ();
  }

  private MenuItem? menu_item_for_pixbuf (Gdk.Pixbuf? pixbuf, Icon icon) {
    if (pixbuf == null)
      return null;

    var image = new Image.from_pixbuf (Contact.frame_icon (pixbuf));
    var menuitem = new MenuItem ();
    menuitem.add (image);
    menuitem.show_all ();
    menuitem.set_data ("source-icon", icon);

    return menuitem;
  }

  private MenuItem? menu_item_for_persona (Persona persona) {
    var details = persona as AvatarDetails;
    if (details == null || details.avatar == null)
      return null;

    try {
      var stream = details.avatar.load (48, null);
      var pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, 48, 48, true);
      return menu_item_for_pixbuf (pixbuf, details.avatar);
    }
    catch {
    }
    return null;
  }

  private MenuItem? menu_item_for_filename (string filename) {
    try {
      var pixbuf = new Gdk.Pixbuf.from_file (filename);
      pixbuf = pixbuf.scale_simple (48, 48, Gdk.InterpType.HYPER);
      return menu_item_for_pixbuf (pixbuf, new FileIcon (File.new_for_path (filename)));
    } catch {
    }
    return null;
  }

  private void pick_avatar_cb (MenuItem menu) {
    Icon icon = menu.get_data<Icon> ("source-icon");
    Value v = Value (icon.get_type ());
    v.set_object (icon);
    Persona? primary_persona = selected_contact.find_primary_persona ();
    if (primary_persona == null)
      primary_persona = new FakePersona (selected_contact);

    set_persona_property.begin (primary_persona,
				"avatar", v, () => {
				});
  }

  private Menu avatar_menu (Contact contact) {
    var menu = new Menu ();

    menu.get_style_context ().add_class ("contact-frame-menu");

    int x = 0;
    int y = 0;
    const int COLUMNS = 5;

    foreach (var p in contact.individual.personas) {
      var menuitem = menu_item_for_persona (p);
      if (menuitem != null) {
	menu.attach (menuitem,
		     x, x + 1, y, y + 1);
	menuitem.show ();
	menuitem.activate.connect (pick_avatar_cb);
	x++;
	if (x >= COLUMNS) {
	  y++;
	  x = 0;
	}
      }
    }

    var system_data_dirs = Environment.get_system_data_dirs ();
    foreach (var data_dir in system_data_dirs) {
      var path = Path.build_filename (data_dir, "pixmaps", "faces");
      Dir? dir = null;
      try {
	dir = Dir.open (path);
      }	catch {
      }
      if (dir != null) {
	string? face;
	while ((face = dir.read_name ()) != null) {
	  var filename = Path.build_filename (path, face);
	  var menuitem = menu_item_for_filename (filename);
	  menu.attach (menuitem,
		       x, x + 1, y, y + 1);
	  menuitem.show ();
	  menuitem.activate.connect (pick_avatar_cb);
	  x++;
	  if (x >= COLUMNS) {
	    y++;
	    x = 0;
	  }
	}
      }
    };

    Utils.add_menu_item (menu,_("Browse for more pictures..."));

    return menu;
  }

  private void display_card (Contact contact) {
    var menu = avatar_menu (contact);

    var image_frame = new ContactFrame (PROFILE_SIZE, menu);
    image_frame.set_image (contact.individual, contact);
    // Put the frame in a grid so its not expanded by the size-group
    var ig = new Grid ();
    ig.add (image_frame);
    card_layout.add_widget_label (ig);

    card_layout.current_row.set_vexpand (false);
    var g = new Grid();
    card_layout.current_row.add (g);

    var l = new Label (null);
    l.set_markup ("<span font='24px'>" + contact.display_name + "</span>");
    l.set_hexpand (true);
    l.set_halign (Align.START);
    l.set_valign (Align.START);
    l.set_margin_top (4);
    l.set_ellipsize (Pango.EllipsizeMode.END);
    l.xalign = 0.0f;
    g.attach (l,  0, 0, 1, 1);

    var nick = contact.individual.nickname;
    if (nick != null && nick.length > 0) {
      l = new Label (null);
      l.set_markup ("<span font='12px' rise='1000'>\xE2\x80\x9C" + nick + "\xE2\x80\x9D</span>");
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
    merged_presence.set_margin_bottom (18);
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
	var value = Value(notes.get_type ());
	value.set_object (notes);
	set_persona_property.begin (persona, "notes", value);
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
    if (primary_persona == null)
      primary_persona = new FakePersona (selected_contact);

    widgets.set (primary_persona, main_text);

    bool primary_note_seen = false;

    foreach (var persona in selected_contact.individual.personas) {
      var notes = persona as NoteDetails;
      if (notes == null)
	continue;
      foreach (var note in notes.notes) {
	if (persona == primary_persona && !primary_note_seen) {
	  primary_note_seen = true;
	  update_note (main_text, note);
	} else if (Contact.persona_has_writable_property (persona, "notes")) {
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

    card_grid.show_all ();
    fields_grid.show_all ();

    ulong id = 0;
    id = this.save_data.connect ( () => {
	save_notes (widgets);
	this.disconnect (id);
      });
  }

  private Persona update_persona_buttons (Contact contact,
					  Persona? _persona) {
    Persona? persona = _persona;

    foreach (var w in edit_persona_grid.get_children ()) {
      w.destroy ();
    }

    var persona_list = new ArrayList<Persona>();
    int i = 0;
    persona_list.add_all (contact.individual.personas);
    while (i < persona_list.size) {
      if (persona_list[i].store.type_id == "key-file")
	persona_list.remove_at (i);
      else
	i++;
    }
    var fake_persona = FakePersona.maybe_create_for (contact);
    if (fake_persona != null)
      persona_list.add (fake_persona);
    persona_list.sort (Contact.compare_persona_by_store);

    foreach (var p in persona_list) {
      if (p.store.is_writeable) {
	editing_persona_primary = p;
      }
    }

    if (persona == null)
      persona = persona_list[0];

    PersonaButton button = null;
    if (persona_list.size > 1) {
      foreach (var p in persona_list) {

	button = new PersonaButton (button, p as AvatarDetails, 48);
	edit_persona_grid.add (button);

	if (p == persona)
	  button.set_active (true);

	button.toggled.connect ( (a_button) => {
	    if (a_button.get_active ())
	      update_edit_details (p, p is FakePersona);
	  });
      }
    }

    edit_persona_grid.show_all ();
    return persona;
  }

  private void display_edit (Contact contact, Persona? _persona, bool new_contact = false) {
    Persona? persona = _persona;
    set_display_mode (DisplayMode.EDIT);

    edit_image_frame = new ContactFrame (PROFILE_SIZE);
    // Put the frame in a grid so its not expanded by the size-group
    var ig = new Grid ();
    ig.add (edit_image_frame);
    card_layout.add_widget_label (ig);

    card_layout.current_row.set_vexpand (false);
    var g = new Grid();
    card_layout.current_row.add (g);

    var e = new Entry ();
    e.get_style_context ().add_class ("contact-entry");
    e.set ("placeholder-text", _("Enter name"));
    e.set_data ("original-text", contact.display_name);
    e.set_text (contact.display_name);
    e.set_hexpand (true);
    e.set_halign (Align.FILL);
    e.set_valign (Align.START);
    g.attach (e,  0, 0, 1, 1);
    if (new_contact)
      e.grab_focus ();

    if (new_contact) {
      var l = new Label ("");
      l.set_markup ("<span font='12px'>" + _("Contact Name") + "</span>");
      l.xalign = 0.0f;
      g.attach (l,  0, 1, 1, 1);
    }

    edit_persona_grid = new Grid ();
    edit_persona_grid.set_row_spacing (0);
    edit_persona_grid.set_halign (Align.START);
    edit_persona_grid.set_valign (Align.END);
    edit_persona_grid.set_vexpand (true);

    persona = update_persona_buttons (contact, persona);
    update_edit_details (persona, new_contact || persona is FakePersona);

    e.focus_out_event.connect ( (ev) => {
	name = e.get_text ();
	if (name != e.get_data<string?> ("original-text")) {
	  Value v = Value (typeof (string));
	  v.set_string (name);
	  set_persona_property.begin (editing_persona_primary,
				      "full-name", v, () => {
				      });
	}
	return false;
      });

    g.attach (edit_persona_grid,  0, 3, 1, 1);
    card_grid.show_all ();
    fields_grid.show_all ();
    button_grid.show_all ();
  }

  private void display_contact (Contact contact) {
    set_display_mode (DisplayMode.DETAILS);
    set_has_notes (!contact.individual.notes.is_empty);
    display_card (contact);

    var emails = Contact.sort_fields<EmailFieldDetails>(contact.individual.email_addresses);
    foreach (var email in emails) {
      var type = TypeSet.general.format_type (email);
      fields_layout.add_label_detail (type, email.value);
      var button = fields_layout.add_button ("mail-unread-symbolic");
      var email_addr = email.value;
      button.clicked.connect ( () => {
	  Utils.compose_mail (email_addr);
	});
    }

    var ims = contact.individual.im_addresses;
    var im_keys = ims.get_keys ();
    foreach (var protocol in im_keys) {
      foreach (var id in ims[protocol]) {
	fields_layout.add_label_detail (_("Chat"), contact.format_im_name (protocol, id.value));
	Button? button = null;
	var presence = contact.create_presence_widget (protocol, id.value);
	if (presence != null) {
	  button = fields_layout.add_button (null);
	  button.add (presence);
	}

	if (button != null) {
	  button.clicked.connect ( () => {
	      Utils.start_chat (contact, protocol, id.value);
	    });
	}

	var callable_account = contact.is_callable (protocol, id.value);
	if (callable_account != null) {
	  Button? button_call = fields_layout.add_button (null);
	  var phone_image = new Image ();
	  phone_image.set_no_show_all (true);
	  phone_image.set_from_icon_name ("audio-input-microphone-symbolic",
	      IconSize.MENU);
	  phone_image.show ();
	  button_call.add (phone_image);
	  button_call.clicked.connect ( () => {
		Utils.start_call_with_account (id.value, callable_account);
	      });
	}
      }
    }

    var phone_numbers = Contact.sort_fields<PhoneFieldDetails>(contact.individual.phone_numbers);
    foreach (var p in phone_numbers) {
      var phone = p as PhoneFieldDetails;
      var type = TypeSet.phone.format_type (phone);
      fields_layout.add_label_detail (type, phone.value);
      if (this.contacts_store.can_call) {
	  Button? button = fields_layout.add_button (null);
	  var phone_image = new Image ();
	  phone_image.set_no_show_all (true);
	  phone_image.set_from_icon_name ("phone-symbolic", IconSize.MENU);
	  phone_image.show ();
	  button.add (phone_image);
	  button.clicked.connect ( () => {
		Utils.start_call (phone.value, this.contacts_store.calling_accounts);
	      });
	}
    }

    var postals = contact.individual.postal_addresses;
    if (!postals.is_empty) {
      foreach (var addr in postals) {
	var type = TypeSet.general.format_type (addr);
	string[] strs = Contact.format_address (addr.value);
	fields_layout.add_label (type);
	if (strs.length > 0) {
	  foreach (var s in strs)
	    fields_layout.add_detail (s);
	}
	var button = fields_layout.add_button ("edit-copy-symbolic");
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
      fields_layout.add_label ("Links");
      foreach (var url_details in urls) {
	fields_layout.add_link (url_details.value, contact.format_uri_link_text (url_details));
      }
    }

    card_grid.show_all ();
    fields_grid.show_all ();
    button_grid.show_all ();
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
    card_layout.reset ();
    fields_layout.reset ();
    button_layout.reset ();

    edit_image_frame = null;
    edit_persona_grid = null;
    editing_persona = null;
    editing_persona_primary = null;

    if (display_mode == mode)
      return;

    display_mode = mode;
    if (mode == DisplayMode.EMPTY) {
      empty_widget.show ();
      pane.hide ();
      normal_buttons.hide ();
      editing_buttons.hide ();
    } else if (mode == DisplayMode.DETAILS) {
      pane.show ();
      empty_widget.hide ();
      normal_buttons.show ();
      editing_buttons.hide ();
      normal_buttons.set_sensitive (mode != DisplayMode.EMPTY);
    } else {
      pane.show ();
      empty_widget.hide ();
      normal_buttons.hide ();
      editing_buttons.show ();
    }
  }

  public void new_contact (ListPane list_pane) {
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
	contact.is_new = true;
	persona.set_data ("contacts-unedited", true);
	display_edit (contact, persona, true);
	list_pane.select_contact (contact, true);

	ulong id = 0;
	id = this.save_data.connect ( () => {
	    if (persona.get_data<bool> ("contacts-unedited") != false) {
	      editing_persona.store.remove_persona.begin (editing_persona, () => {
		});
	    }
	    this.disconnect (id);
	  });
      });

  }

  public void show_contact (Contact? new_contact, bool edit=false) {
    if (new_contact != null)
      new_contact.is_new = false;
    this.save_data (); // Ensure all edit data saved

    if (selected_contact != null)
      selected_contact.changed.disconnect (selected_contact_changed);

    selected_contact = new_contact;
    set_display_mode (DisplayMode.EMPTY);
    set_has_notes (false);

    if (selected_contact != null) {
	display_contact (selected_contact);
	selected_contact.changed.connect (selected_contact_changed);
    }
  }

  public ContactPane (Store contacts_store) {
    this.contacts_store = contacts_store;

    this.set_orientation (Orientation.VERTICAL);

    pane = new EventBox ();
    pane.set_no_show_all (true);
    pane.get_style_context ().add_class ("contact-pane");
    this.add (pane);

    var image = new Image.from_icon_name ("avatar-default-symbolic", IconSize.MENU);
    image.set_sensitive (false);
    image.set_pixel_size (80);
    image.set_no_show_all (true);
    image.set_hexpand (true);
    image.set_vexpand (true);
    this.add (image);
    empty_widget = image;

    var grid = new Grid ();
    grid.set_border_width (10);
    pane.add (grid);

    var scrolled = new ScrolledWindow (null, null);
    scrolled.set_hexpand (true);
    scrolled.set_vexpand (true);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    grid.attach (scrolled, 0, 1, 1, 1);

    var top_grid = new Grid ();
    top_grid.set_orientation (Orientation.VERTICAL);
    scrolled.add_with_viewport (top_grid);
    scrolled.get_child().get_style_context ().add_class ("contact-pane");

    layout_state = new DetailsLayout.SharedState ();
    card_layout = new DetailsLayout (layout_state);
    fields_layout = new DetailsLayout (layout_state);
    button_layout = new DetailsLayout (layout_state);

    card_grid = card_layout.grid;
    top_grid.add (card_grid);

    fields_grid = fields_layout.grid;
    top_grid.add (fields_grid);

    button_grid = button_layout.grid;
    top_grid.add (button_grid);

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
    //Utils.add_menu_item (menu,_("Send..."));
    Utils.add_menu_item (menu,_("Delete")).set_sensitive (false);

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
