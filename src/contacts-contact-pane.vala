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

    var button = new ToggleButton ();
    button.set_focus_on_click (false);
    button.get_style_context ().add_class ("contact-frame-button");
    button.add (image);
    button.set_mode (false);
    this.add (button);

    button.toggled.connect ( () => {
	if (this.menu == null) {
	  if (button.get_active ())
	    button.set_active (false);
	  return;
	}

	if (button.get_active ()) {
	  if (!popup_in_progress) {
	    menu.popup (null, null, menu_position, 1, Gtk.get_current_event_time ());
	  }
	} else {
	  menu.popdown ();
	}
      });

    button.button_press_event.connect ( (event) => {
	if (this.menu == null)
	  return true;
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
	if (this.menu == null)
	  return false;

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

    if (menu != null) {
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

public class Contacts.AvatarMenu : Menu {
  private Gnome.DesktopThumbnailFactory thumbnail_factory;

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

  public signal void icon_set (Icon icon);

  private void set_avatar_from_icon (Icon icon) {
    icon_set (icon);
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

  public AvatarMenu (Contact contact) {
    thumbnail_factory = new Gnome.DesktopThumbnailFactory (Gnome.ThumbnailSize.NORMAL);

    this.get_style_context ().add_class ("contact-frame-menu");

    int x = 0;
    int y = 0;
    const int COLUMNS = 5;

    foreach (var p in contact.individual.personas) {
      var menuitem = menu_item_for_persona (p);
      if (menuitem != null) {
	this.attach (menuitem,
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
	  this.attach (menuitem,
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

    Utils.add_menu_item (this,_("Browse for more pictures...")).activate.connect (select_avatar_file_cb);
  }
}

public class Contacts.FieldRow : Contacts.Row {
  int start;

  public FieldRow(RowGroup group) {
    base (group);

    start = 0;
  }

  public void pack (Widget w) {
    this.attach (w, 1, start++);
  }

  public void label (string s) {
    var l = new Label (s);
    l.set_halign (Align.START);
    l.get_style_context ().add_class ("dim-label");
    pack (l);
  }

  public void header (string s) {
    var l = new Label (s);
    l.set_markup (
      "<span font='24px'>%s</span>".printf (s));
    l.set_halign (Align.START);
    pack (l);
  }

  public void text (string s, bool wrap = false) {
    var l = new Label (s);
    if (wrap) {
      l.set_line_wrap (true);
      l.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    } else {
      l.set_ellipsize (Pango.EllipsizeMode.END);
    }
    l.set_halign (Align.START);
    pack (l);
  }

  public void text_detail (string text, string detail, bool wrap = false) {
    var grid = new Grid ();

    var l = new Label (text);
    l.set_hexpand (true);
    l.set_halign (Align.START);
    if (wrap) {
      l.set_line_wrap (true);
      l.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    } else {
      l.set_ellipsize (Pango.EllipsizeMode.END);
    }
    grid.add (l);

    l = new Label (detail);
    l.set_halign (Align.END);
    l.get_style_context ().add_class ("dim-label");

    grid.set_halign (Align.FILL);
    grid.add (l);

    pack (grid);
  }

  public void left_add (Widget widget) {
    this.attach (widget, 0, 0);
    widget.set_halign (Align.END);
  }

  public void right_add (Widget widget) {
    this.attach (widget, 2, 0);
    widget.set_halign (Align.START);
  }
}

public class Contacts.PersonaSheet : Grid {
  ContactPane pane;
  Persona persona;
  FieldRow header;
  FieldRow footer;

  abstract class Field : Grid {
    public class string label_name;

    public PersonaSheet sheet { get; construct; }
    public int row_nr { get; construct; }
    public bool added;
    FieldRow label_row;

    public abstract void populate ();

    construct {
      this.set_orientation (Orientation.VERTICAL);

      label_row = new FieldRow (sheet.pane.row_group);
      this.add (label_row);
      label_row.label (label_name);
    }

    public void add_to_sheet () {
      sheet.attach (this, 0, row_nr, 1, 1);
      added = true;
    }

    public bool is_empty () {
      return get_children ().length () == 1;
    }

    public void clear () {
      foreach (var row in get_children ()) {
	if (row != label_row)
	  row.destroy ();
      }
    }

    public FieldRow new_row () {
      var row = new FieldRow (sheet.pane.row_group);
      this.add (row);
      return row;
    }
  }

  class LinkField : Field {
    class construct {
      label_name = _("Links");
    }
    public override void populate () {
      var details = sheet.persona as UrlDetails;
      if (details == null)
	return;

      var urls = details.urls;
      foreach (var url_details in urls) {
	var row = new_row ();
	row.text (Contact.format_uri_link_text (url_details));
	//row.detail ("Blog");
	// Add link to url_details.value
	var image = new Image.from_icon_name ("web-browser" /* -symbolic */, IconSize.MENU);
	image.get_style_context ().add_class ("dim-label");
	var button = new Button();
	button.set_relief (ReliefStyle.NONE);
	button.add (image);
	row.right_add (button);
      }
    }
  }

  class EmailField : Field {
    class construct {
      label_name = _("Email");
    }
    public override void populate () {
      var details = sheet.persona as EmailDetails;
      if (details == null)
	return;
      var emails = Contact.sort_fields<EmailFieldDetails>(details.email_addresses);
      foreach (var email in emails) {
	var row = new_row ();
	row.text_detail (email.value, TypeSet.general.format_type (email));
      }
    }
  }

  class PhoneField : Field {
    class construct {
      label_name = _("Phone");
    }
    public override void populate () {
      var details = sheet.persona as PhoneDetails;
      if (details == null)
	return;
      var phone_numbers = Contact.sort_fields<PhoneFieldDetails>(details.phone_numbers);
      foreach (var phone in phone_numbers) {
	var row = new_row ();
	row.text_detail (phone.value, TypeSet.phone.format_type (phone));
      }
    }
  }

  class ChatField : Field {
    class construct {
      label_name = _("Chat");
    }
    public override void populate () {
      var details = sheet.persona as ImDetails;
      if (details == null)
	return;
      var ims = details.im_addresses;
      var im_keys = ims.get_keys ();
      foreach (var protocol in im_keys) {
	foreach (var id in ims[protocol]) {
	  var im_persona = sheet.persona as Tpf.Persona;
	  if (im_persona == null)
	    continue;
	  var row = new_row ();
	  row.text (Contact.format_im_name (im_persona, protocol, id.value));
	}
      }
    }
  }

  class BirthdayField : Field {
    class construct {
      label_name = _("Birthday");
    }
    public override void populate () {
      var details = sheet.persona as BirthdayDetails;
      if (details == null)
	return;

      DateTime? bday = details.birthday;
      if (bday != null) {
	var row = new_row ();
	row.text (bday.to_local ().format ("%x"));

	var image = new Image.from_icon_name ("preferences-system-date-and-time-symbolic", IconSize.MENU);
	image.get_style_context ().add_class ("dim-label");
	var button = new Button();
	button.set_relief (ReliefStyle.NONE);
	button.add (image);
	row.right_add (button);
      }
    }
  }

  class NicknameField : Field {
    class construct {
      label_name = _("Nickname");
    }
    public override void populate () {
      var details = sheet.persona as NameDetails;
      if (details == null)
	return;

      if (is_set (details.nickname)) {
	var row = new_row ();
	row.text (details.nickname);
      }
    }
  }

  class NoteField : Field {
    class construct {
      label_name = _("Note");
    }
    public override void populate () {
      var details = sheet.persona as NoteDetails;
      if (details == null)
	return;

      foreach (var note in details.notes) {
	var row = new_row ();
	row.text (note.value, true);
      }
    }
  }

  class AddressField : Field {
    class construct {
      label_name = _("Addresses");
    }
    public override void populate () {
      var details = sheet.persona as PostalAddressDetails;
      if (details == null)
	return;

      foreach (var addr in details.postal_addresses) {
	var row = new_row ();
	string[] strs = Contact.format_address (addr.value);
	int i = 0;
	foreach (var s in strs) {
	  if (i++ == 0)
	    row.text_detail (s, TypeSet.general.format_type (addr), true);
	  else
	    row.text (s, true);
	}
      }
    }
  }

  static Type[] field_types = {
    typeof(LinkField),
    typeof(EmailField),
    typeof(PhoneField),
    typeof(ChatField),
    typeof(BirthdayField),
    typeof(NicknameField),
    typeof(AddressField),
    typeof(NoteField)
    /* More:
       company/department/profession/title/manager/assistant
    */
  };

  Field fields[8]; // This is really the size of field_types enum

  public PersonaSheet(ContactPane pane, Persona persona) {
    assert (fields.length == field_types.length);

    this.pane = pane;
    this.persona = persona;

    this.set_orientation (Orientation.VERTICAL);
    this.set_row_spacing (16);

    int row_nr = 0;

    bool editable =
      Contact.persona_has_writable_property (persona, "email-addresses") &&
      Contact.persona_has_writable_property (persona, "phone-numbers") &&
      Contact.persona_has_writable_property (persona, "postal-addresses");

    if (!persona.store.is_primary_store) {
      header = new FieldRow (pane.row_group);
      this.attach (header, 0, row_nr++, 1, 1);

      header.header (Contact.format_persona_store_name (persona.store));

      if (!editable) {
	var image = new Image.from_icon_name ("changes-prevent-symbolic", IconSize.MENU);

	image.get_style_context ().add_class ("dim-label");
	image.set_valign (Align.CENTER);
	header.left_add (image);
      }
    }

    for (int i = 0; i < field_types.length; i++) {
      var field = (Field) Object.new(field_types[i], sheet: this, row_nr: row_nr++);

      field.populate ();
      if (!field.is_empty ())
	field.add_to_sheet ();
    }

    if (editable) {
      footer = new FieldRow (pane.row_group);
      this.attach (footer, 0, row_nr++, 1, 1);

      var b = new Button.with_label ("Add detail...");
      b.set_halign (Align.START);

      footer.pack (b);
    }

  }
}


public class Contacts.ContactPane : ScrolledWindow {
  private Store contacts_store;
  private Grid top_grid;
  private Grid card_grid;
  private Grid personas_grid;
  public RowGroup row_group;

  private Contact? contact;

  const int PROFILE_SIZE = 128;

 private async Persona? set_persona_property (Persona persona,
					       string property_name,
					       Value value) throws GLib.Error, PropertyError {
    contact.is_unedited = false;
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
    contact.is_unedited = false;
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

  public void update_card () {
    foreach (var w in card_grid.get_children ()) {
      w.destroy ();
    }

    if (contact == null)
      return;

    var menu = new AvatarMenu (contact);
    menu.icon_set.connect ( (icon) => {
	Value v = Value (icon.get_type ());
	v.set_object (icon);
	set_individual_property.begin (contact,
				       "avatar", v, () => {
				       });
      });

    var image_frame = new ContactFrame (PROFILE_SIZE, menu);
    image_frame.set_image (contact.individual, contact);

    card_grid.attach (image_frame,  0, 0, 1, 3);
    card_grid.set_row_spacing (16);

    var l = new Label (null);
    l.set_markup ("<span font='24px'>" + contact.display_name + "</span>");
    l.set_hexpand (true);
    l.set_halign (Align.START);
    l.set_valign (Align.START);
    l.set_margin_top (4);
    l.set_ellipsize (Pango.EllipsizeMode.END);
    l.xalign = 0.0f;
    card_grid.attach (l,  1, 0, 1, 1);

    var merged_presence = contact.create_merged_presence_widget ();
    merged_presence.set_halign (Align.START);
    merged_presence.set_valign (Align.START);
    merged_presence.set_vexpand (true);
    merged_presence.set_margin_bottom (18);
    card_grid.attach (merged_presence,  1, 1, 1, 1);

    var box = new Box (Orientation.HORIZONTAL, 0);

    box.get_style_context ().add_class ("linked");
    var image = new Image.from_icon_name ("mail-unread-symbolic", IconSize.MENU);
    var b = new Button ();
    b.add (image);
    b.set_hexpand (true);
    box.pack_start (b, true, true, 0);

    image = new Image.from_icon_name ("user-available-symbolic", IconSize.MENU);
    b = new Button ();
    b.add (image);
    box.pack_start (b, true, true, 0);

    image = new Image.from_icon_name ("call-start-symbolic", IconSize.MENU);
    b = new Button ();
    b.add (image);
    box.pack_start (b, true, true, 0);

    card_grid.attach (box,  1, 2, 1, 1);

    card_grid.show_all ();
  }

  public void update_personas () {
    foreach (var w in personas_grid.get_children ()) {
      w.destroy ();
    }

    if (contact == null)
      return;

    var personas = contact.get_personas_for_display ();

    foreach (var p in personas) {
      var sheet = new PersonaSheet(this, p);
      personas_grid.add (sheet);
    }

    personas_grid.show_all ();
  }

  public void show_contact (Contact? new_contact, bool edit=false) {
    contact = new_contact;

    update_card ();
    update_personas ();
  }

  public void new_contact (ListPane list_pane) {
  }

  public ContactPane (Store contacts_store) {
    this.contacts_store = contacts_store;
    row_group = new RowGroup(3);
    row_group.set_column_min_width (0, 32);
    row_group.set_column_min_width (1, 400);
    row_group.set_column_max_width (1, 450);
    row_group.set_column_min_width (2, 32);
    row_group.set_column_spacing (0, 8);
    row_group.set_column_spacing (1, 8);

    this.set_hexpand (true);
    this.set_vexpand (true);
    this.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

    top_grid = new Grid ();
    top_grid.set_orientation (Orientation.VERTICAL);
    top_grid.set_margin_left (10);
    top_grid.set_margin_top (10);
    top_grid.set_margin_bottom (10);
    top_grid.set_row_spacing (20);
    this.add_with_viewport (top_grid);

    this.get_child().get_style_context ().add_class ("contact-pane");

    var top_row = new FieldRow (row_group);
    top_grid.add (top_row);
    card_grid = new Grid ();
    card_grid.set_vexpand (false);
    top_row.pack (card_grid);

    personas_grid = new Grid ();
    personas_grid.set_orientation (Orientation.VERTICAL);
    personas_grid.set_row_spacing (40);
    top_grid.add (personas_grid);

    top_grid.show_all ();
  }
}
