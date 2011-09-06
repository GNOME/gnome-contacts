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
  // TODO: Remove later when bound in vala
  private static unowned string C_(string context, string msgid) {
    return GLib.dpgettext2 (Config.GETTEXT_PACKAGE, context, msgid);
  }
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
  private Gnome.DesktopThumbnailFactory thumbnail_factory;
  /* Stuff used only in edit mode */
  private ContactFrame edit_image_frame;
  private Grid edit_persona_grid;
  private Persona? editing_persona;
  private Persona? editing_persona_primary;
  private MenuItem delete_menu_item;

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
					       Value value) throws GLib.Error, PropertyError {
    selected_contact.is_unedited = false;
    if (persona is FakePersona) {
      var fake = persona as FakePersona;
      return yield fake.make_real_and_set (property_name, value);
    } else {
      persona.set_data ("contacts-unedited", true);
      yield Contact.set_persona_property (persona, property_name, value);
      return null;
    }
  }

  /* Tries to set the property on all persons that have it writeable, and
   * if none, creates a new persona and writes to it, returning the new
   * persona.
   */
  private async Persona? set_individual_property (Contact contact,
						  string property_name,
						  Value value) throws GLib.Error, PropertyError {
    selected_contact.is_unedited = false;
    bool did_set = false;
    foreach (var p in contact.individual.personas) {
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

  private void update_property (string property_name,
				Value value) {
    var editing_backup = editing_persona;
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
          } catch (PropertyError e1) {
            warning ("Unable to edit property '%s': %s", property_name, e1.message);
          } catch (Error e2) {
            warning ("Unable to create writeable persona: %s", e2.message);
	  }
      });
  }

  private void update_string_property (string property_name,
				       string string_value) {
    var value = Value (typeof (string));
    value.set_string (string_value);
    update_property (property_name, value);
  }

  private void update_detail_property (string property_name,
				       Set<AbstractFieldDetails> detail_set) {
    var value = Value (detail_set.get_type ());
    value.set_object (detail_set);
    update_property (property_name, value);
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

  private Widget add_detail_editor (DetailsLayout layout,
				    TypeSet type_set,
				    Set<AbstractFieldDetails> detail_set,
				    AbstractFieldDetails<string> detail,
				    string property_name,
				    string? placeholder_text) {
    detail_set.add (detail);
    add_detail_combo (layout, type_set, detail_set, detail, property_name);
    var main = add_detail_entry (layout, detail_set, detail, property_name, placeholder_text);
    add_detail_remove (layout, detail_set, detail, property_name);

    return main;
  }

  private Widget add_detail_editor_no_type (DetailsLayout layout,
					    Set<AbstractFieldDetails> detail_set,
					    AbstractFieldDetails<string> detail,
					    string property_name,
					    string? placeholder_text) {
    detail_set.add (detail);
    var main = add_detail_entry (layout, detail_set, detail, property_name, placeholder_text);
    add_detail_remove (layout, detail_set, detail, property_name, false);

    return main;
  }

  private Entry add_string_entry (DetailsLayout layout,
				  string property_name,
				  string value,
				  string? placeholder_text) {
    var entry = layout.add_entry (value);
    entry.set_data ("original-text", value);
    if (placeholder_text != null)
      entry.set ("placeholder-text", placeholder_text);

    entry.focus_out_event.connect ( (ev) => {
	if (entry.get_data<string?> ("original-text") !=
	    entry.get_text ()) {
	  var s = entry.get_text ();
	  entry.set_data ("original-text", s);
	  update_string_property (property_name, s);
	}
	return false;
      });
    return entry;
  }

  private Button add_string_remove (DetailsLayout layout,
				    string property_name,
				    bool at_top = true) {
    var remove_button = layout.add_remove (at_top);
    var row = layout.current_row;

    remove_button.clicked.connect ( () => {
	update_string_property (property_name, "");
	row.destroy ();
      });
    return remove_button;
  }

  private Widget add_string_editor (DetailsLayout layout,
				    string label,
				    string property_name,
				    string value,
				    string? placeholder_text,
				    bool add_remove = true) {
    layout.add_label (label);
    var main = add_string_entry (layout, property_name, value, placeholder_text);
    if (add_remove)
      add_string_remove (layout, property_name);

    return main;
  }

  private Widget add_nickname_editor (DetailsLayout layout,
				      string nickname) {
    return add_string_editor (layout,
			      _("Nickname"),
			      "nickname",
			      nickname,
			      _("Enter nickname"));
  }

  private Widget add_alias_editor (DetailsLayout layout,
				   string alias) {
    return add_string_editor (layout,
			      _("Alias"),
			      "alias",
			      alias,
			      _("Enter alias"),
			      false);
  }

  private Widget add_email_editor (DetailsLayout layout,
				   Set<AbstractFieldDetails> detail_set,
				   EmailFieldDetails? email) {
    return add_detail_editor (layout,
			      TypeSet.general,
			      detail_set,
			      email != null ? new EmailFieldDetails (email.value, email.parameters) : new EmailFieldDetails(""),
			      "email-addresses",
			      _("Enter email address"));
  }

  private Widget add_phone_editor (DetailsLayout layout,
				   Set<AbstractFieldDetails> detail_set,
				   PhoneFieldDetails? p) {
    return add_detail_editor (layout,
			      TypeSet.phone,
			      detail_set,
			      p != null ? new PhoneFieldDetails (p.value, p.parameters) : new PhoneFieldDetails(""),
			      "phone-numbers",
			      _("Enter phone number"));
  }

  private Widget add_url_editor (DetailsLayout layout,
				 Set<AbstractFieldDetails> detail_set,
				 UrlFieldDetails? url) {
    if (layout.grid.get_children ().length () == 0)
      layout.add_label (_("Links"));

    return add_detail_editor_no_type (layout,
				      detail_set,
				      url != null ? new UrlFieldDetails (url.value, url.parameters) : new UrlFieldDetails (""),
				      "urls",
				      _("Enter link"));
  }

  private Widget add_postal_editor (DetailsLayout layout,
				    Set<PostalAddressFieldDetails> detail_set,
				    PostalAddressFieldDetails detail) {
    string[] props = {"street", "extension", "locality", "region", "postal_code", "po_box", "country"};
    string[] nice = {_("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

    detail_set.add (detail);
    add_detail_combo (layout, TypeSet.general, detail_set, detail, "postal-addresses");

    Widget main = null;
    layout.begin_detail_box ();
    for (int i = 0; i < props.length; i++) {
      var e = add_detail_postal_entry (layout,
				       detail_set,
				       detail,
				       props[i],
				       "postal-addresses",
				       nice[i]);
      if (i == 0)
	main = e;
    }
    layout.end_detail_box ();
    var button = add_detail_remove (layout, detail_set, detail, "postal-addresses");
    button.set_valign (Align.START);

    return main;
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

    var nick_layout = new DetailsLayout (layout_state);
    fields_grid.add (nick_layout.grid);

    var name_details = persona as NameDetails;
    if (name_details != null) {
      var nick = name_details.nickname;
      if (nick != null && nick != "") {
	add_nickname_editor (nick_layout, nick);
      }
    }

    var alias_layout = new DetailsLayout (layout_state);
    fields_grid.add (alias_layout.grid);

    var alias_details = persona as AliasDetails;
    if (alias_details != null) {
      var alias = alias_details.alias;
      if (alias != null && alias != "") {
	add_alias_editor (alias_layout, alias);
      }
    }

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

    var birthdate_layout = new DetailsLayout (layout_state);
    fields_grid.add (birthdate_layout.grid);

    var birthdate_details = persona as BirthdayDetails;
    if (birthdate_details != null) {
      DateTime? bday = birthdate_details.birthday;
      /* TODO: Implement GUI for this, needs a date picker widget (#657972)*/
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
	    var widget = add_email_editor (email_layout,
					   editing_emails, null);
	    widget.grab_focus ();
	    email_layout.grid.show_all ();
	  });
      }
      if (Contact.persona_has_writable_property (persona, "phone-numbers")) {
	Utils.add_menu_item (menu, _("Phone number")).activate.connect ( () => {
	    var widget = add_phone_editor (phone_layout,
					   editing_phones, null);
	    widget.grab_focus ();
	    phone_layout.grid.show_all ();
	  });
      }
      if (Contact.persona_has_writable_property (persona, "postal-addresses")) {
	Utils.add_menu_item (menu, _("Postal Address")).activate.connect ( () => {
	    var widget = add_postal_editor (postal_layout,
					    editing_postals,
					    new PostalAddressFieldDetails(new PostalAddress (null, null, null, null, null, null, null, null, null),
									  null));
	    widget.grab_focus ();
	    postal_layout.grid.show_all ();
	  });
      }
      if (Contact.persona_has_writable_property (persona, "urls")) {
	Utils.add_menu_item (menu, C_ ("url-link", "Link")).activate.connect ( () => {
	    var widget = add_url_editor (url_layout,
					 editing_urls,
					 null);
	    widget.grab_focus ();
	    url_layout.grid.show_all ();
	  });
      }
      MenuItem nick_menu_item = null;
      if (name_details != null &&
	  Contact.persona_has_writable_property (persona, "nickname")) {
	nick_menu_item = Utils.add_menu_item (menu, _("Nickname"));
	nick_menu_item.activate.connect ( () => {
	    var widget = add_nickname_editor (nick_layout, "");
	    widget.grab_focus ();
	    nick_layout.grid.show_all ();
	  });
      }

      menu_button.popup.connect ( () => {
	  if (nick_menu_item != null) {
	    if (name_details.nickname != null &&
		name_details.nickname != "")
	      nick_menu_item.hide ();
	    else
	      nick_menu_item.show ();
	  }
	});

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

  private void set_avatar_from_icon (Icon icon) {
    Value v = Value (icon.get_type ());
    v.set_object (icon);
    set_individual_property.begin (selected_contact,
				   "avatar", v, () => {
				   });
  }

  private void pick_avatar_cb (MenuItem menu) {
    Icon icon = menu.get_data<Icon> ("source-icon");
    set_avatar_from_icon (icon);
  }

  public void update_preview (FileChooser chooser) {
    var uri = chooser.get_preview_uri ();
    if (uri != null) {
      Gdk.Pixbuf? pixbuf = null;

      var preview = chooser.get_preview_widget () as Image;

      var file = File.new_for_uri (uri);
      try {
	var file_info = file.query_info (GLib.FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE,
					 FileQueryInfoFlags.NONE, null);
	if (file_info != null) {
	  var mime_type = file_info.get_content_type ();

	  if (mime_type != null)
	    pixbuf = thumbnail_factory.generate_thumbnail (uri, mime_type);
	}
      } catch (GLib.Error e) {
      }

      (chooser as Dialog).set_response_sensitive (ResponseType.ACCEPT,
						  (pixbuf != null));

      if (pixbuf != null)
	preview.set_from_pixbuf (pixbuf);
      else
	preview.set_from_stock (Stock.DIALOG_QUESTION,
				IconSize.DIALOG);
    }

    chooser.set_preview_widget_active (true);
  }

  private void select_avatar_file_cb (MenuItem menu) {
    var chooser = new FileChooserDialog (_("Browse for more pictures"),
					 (Window)this.get_toplevel (),
					 FileChooserAction.OPEN,
					 Stock.CANCEL, ResponseType.CANCEL,
					 Stock.OPEN, ResponseType.ACCEPT);
    chooser.set_modal (true);
    chooser.set_local_only (false);
    var preview = new Image ();
    preview.set_size_request (128, -1);
    chooser.set_preview_widget (preview);
    chooser.set_use_preview_label (false);
    preview.show ();

    chooser.update_preview.connect (update_preview);

    var folder = Environment.get_user_special_dir (UserDirectory.PICTURES);
    if (folder != null)
      chooser.set_current_folder (folder);

    chooser.response.connect ( (response) => {
	if (response != ResponseType.ACCEPT) {
	  chooser.destroy ();
	  return;
	}
	var icon = new FileIcon (File.new_for_uri (chooser.get_uri ()));
	set_avatar_from_icon (icon);
	chooser.destroy ();
      });

    chooser.present ();
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

    Utils.add_menu_item (menu,_("Browse for more pictures...")).activate.connect (select_avatar_file_cb);

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

    var secondary = contact.get_secondary_string ();
    if (secondary != null) {
      l = new Label (null);
      l.set_markup ("<span font='12px' rise='1000'>"+secondary+"</span>");
      l.set_halign (Align.START);
      l.set_valign (Align.START);
      l.set_ellipsize (Pango.EllipsizeMode.END);
      l.xalign = 0.0f;
      g.attach (l,  0, 1, 1, 1);
    }

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

    // We store the main note on the primay persona if any, otherwise
    // on the first persona with a writable notes, falling back to
    // a FakePersona that creates a primary persona as needed
    Persona? notes_persona = selected_contact.find_primary_persona ();
    if (notes_persona == null) {
      foreach (var persona in selected_contact.individual.personas) {
	if (Contact.persona_has_writable_property (persona, "notes")) {
	  notes_persona = persona;
	  break;
	}
      }
      if (notes_persona == null)
	notes_persona = new FakePersona (selected_contact);
    }

    widgets.set (notes_persona, main_text);

    bool notes_persona_note_seen = false;

    foreach (var persona in selected_contact.individual.personas) {
      var notes = persona as NoteDetails;
      if (notes == null)
	continue;
      foreach (var note in notes.notes) {
	if (persona == notes_persona && !notes_persona_note_seen) {
	  notes_persona_note_seen = true;
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
	  e.set_data ("original-text", name);
	  Value v = Value (typeof (string));
	  v.set_string (name);
	  set_individual_property.begin (selected_contact,
					 "full-name", v,
					 (obj, result) => {
	  try {
	    var p = set_individual_property.end (result);
	    if (p != null &&
		selected_contact == contact &&
		display_mode == DisplayMode.EDIT) {
	      if (editing_persona is FakePersona)
		editing_persona = p;
	      editing_persona_primary = p;
	      update_persona_buttons (selected_contact, editing_persona);
	    }
	  } catch (Error e) {
	    warning ("Unable to create writeable persona: %s", e.message);
	  }
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

    bool can_remove = false;
    bool can_remove_all = true;
    foreach (var p in contact.individual.personas) {
      if (p.store.can_remove_personas == MaybeBool.TRUE &&
	  !(p is Tpf.Persona)) {
	can_remove = true;
      } else {
	can_remove_all = false;
      }
    }
    can_remove_all = can_remove && can_remove_all;

    delete_menu_item.set_sensitive (can_remove_all);

    var nickname = contact.individual.nickname;
    if (nickname != null && nickname != "" &&
	contact.get_secondary_string_source () != "nickname")
      fields_layout.add_label_detail (_("Nickname"), nickname);

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

    DateTime? bday = contact.individual.birthday;
    if (bday != null) {
      fields_layout.add_label (_("Birthday"));
      fields_layout.add_detail (bday.format ("%x"));
    }

    var roles_details = contact.individual.roles;
    foreach (var role_detail in roles_details) {
      var role = role_detail.value;
      if (role.organisation_name != null &&
	  role.organisation_name != "") {
	fields_layout.add_label (_("Company"));
	fields_layout.add_detail (role.organisation_name);
      }
      var org_units = role_detail.get_parameter_values ("org_unit");
      if (org_units != null) {
	foreach (var org_unit in org_units) {
	  if (org_unit != null &&
	      org_unit != "") {
	    fields_layout.add_label (_("Department"));
	    fields_layout.add_detail (org_unit);
	  }
	}
      }
      if (role.role != null &&
	  role.role != "") {
	fields_layout.add_label (_("Profession"));
	fields_layout.add_detail (role.role);
      }
      if (role.title != null &&
	  role.title != "") {
	fields_layout.add_label (_("Title"));
	fields_layout.add_detail (role.title);
      }
      var managers = role_detail.get_parameter_values ("manager");
      if (managers != null) {
	foreach (var manager in managers) {
	  if (manager != null &&
	      manager != "") {
	    fields_layout.add_label (_("Manager"));
	    fields_layout.add_detail (manager);
	  }
	}
      }
      var assistants = role_detail.get_parameter_values ("assistant");
      if (assistants != null) {
	foreach (var assistant in assistants) {
	  if (assistant != null &&
	      assistant != "") {
	    fields_layout.add_label (_("Assistant"));
	    fields_layout.add_detail (assistant);
	  }
	}
      }
    }

    var urls = contact.individual.urls;
    if (!urls.is_empty) {
      fields_layout.add_label (_("Links"));
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
	contact.is_unedited = true;
	display_edit (contact, persona, true);
	list_pane.select_contact (contact, true);

	ulong id = 0;
	id = this.save_data.connect ( () => {
	    if (contact.is_unedited) {
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

    delete_menu_item.set_sensitive (false);

    if (selected_contact != null) {
	display_contact (selected_contact);
	selected_contact.changed.connect (selected_contact_changed);
    }
  }

  public ContactPane (Store contacts_store) {
    thumbnail_factory = new Gnome.DesktopThumbnailFactory (Gnome.ThumbnailSize.NORMAL);
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
    top_grid.set_focus_vadjustment (scrolled.get_vadjustment ());
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
    delete_menu_item = Utils.add_menu_item (menu,_("Delete"));
    delete_menu_item.activate.connect (delete_contact);

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

  void delete_contact () {
    contacts_store.aggregator.remove_individual (selected_contact.individual);
  }

}
