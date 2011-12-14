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
  Clickable clickable;
  int start;

  public FieldRow(RowGroup group) {
    base (group);
    set_redraw_on_allocate (true); // Since we draw the focus rect

    clickable = new Clickable (this);
    clickable.set_focus_on_click (true);
    clickable.clicked.connect ( () => { this.clicked (); } );
    start = 0;

    /* This should really be in class construct, but that doesn't seem to work... */
    activate_signal = GLib.Signal.lookup ("activate-row", typeof (FieldRow));
  }

  public void reset () {
    start = 0;
  }

  public signal void clicked ();

  [CCode (action_signal = true)]
  public virtual signal void activate_row () {
    clickable.activate ();
  }

  public override void realize () {
    base.realize ();
    clickable.realize_for (event_window);
  }

  public override void unrealize () {
    base.unrealize ();
    clickable.unrealize (null);
  }

  public override bool draw (Cairo.Context cr) {
    Allocation allocation;
    this.get_allocation (out allocation);

    var context = this.get_style_context ();
    var state = this.get_state_flags ();

    if (this.has_visible_focus ())
      Gtk.render_focus (context, cr, 0, 0, allocation.width, allocation.height);

    context.save ();
    // Don't propagate the clicked prelight and active state to children
    this.set_state_flags (state & ~(StateFlags.PRELIGHT | StateFlags.ACTIVE), true);
    base.draw (cr);
    context.restore ();

    return true;
  }

  public void pack (Widget w) {
    this.attach (w, 1, start++);
  }

  public void pack_label (string s) {
    var l = new Label (s);
    l.set_halign (Align.START);
    l.get_style_context ().add_class ("dim-label");
    pack (l);
  }

  public void pack_header (string s) {
    var l = new Label (s);
    l.set_markup (
      "<span font='24px'>%s</span>".printf (s));
    l.set_halign (Align.START);
    pack (l);
  }

  public Label pack_text (bool wrap = false) {
    var l = new Label ("");
    if (wrap) {
      l.set_line_wrap (true);
      l.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    } else {
      l.set_ellipsize (Pango.EllipsizeMode.END);
    }
    l.set_halign (Align.START);
    pack (l);
    return l;
  }

  public void pack_text_detail (out Label text_label, out Label detail_label, bool wrap = false) {
    var grid = new Grid ();

    var l = new Label ("");
    l.set_hexpand (true);
    l.set_halign (Align.START);
    if (wrap) {
      l.set_line_wrap (true);
      l.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    } else {
      l.set_ellipsize (Pango.EllipsizeMode.END);
    }
    grid.add (l);

    text_label = l;

    l = new Label ("");
    l.set_halign (Align.END);
    l.get_style_context ().add_class ("dim-label");
    detail_label = l;

    grid.set_halign (Align.FILL);
    grid.add (l);

    pack (grid);
  }

  public void pack_entry_detail_combo (string text, AbstractFieldDetails detail, TypeSet type_set, out Entry entry, out TypeCombo combo) {
    var grid = new Grid ();
    grid.set_column_spacing (16);

    entry = new Entry ();
    entry.set_text (text);
    entry.set_hexpand (true);
    entry.set_halign (Align.FILL);
    grid.add (entry);

    combo = new TypeCombo (type_set);
    combo.set_hexpand (false);
    combo.set_halign (Align.END);
    combo.set_active (detail);

    grid.set_halign (Align.FILL);
    grid.add (combo);

    pack (grid);
  }

  public Entry pack_entry (string s) {
    var e = new Entry ();
    e.set_text (s);
    e.set_halign (Align.FILL);
    pack (e);
    return e;
  }

  public void left_add (Widget widget) {
    this.attach (widget, 0, 0);
    widget.set_halign (Align.END);
  }

  public void right_add (Widget widget) {
    this.attach (widget, 2, 0);
    widget.set_halign (Align.START);
  }

  public Button pack_delete_button () {
    var image = new Image.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    var b = new Button();
    b.add (image);
    right_add (b);
    b.set_halign (Align.CENTER);
    return b;
  }
}

public abstract class Contacts.FieldSet : Grid {
  public class string label_name;
  public class string property_name;

  public PersonaSheet sheet { get; construct; }
  public int row_nr { get; construct; }
  public bool added;
  public bool saving;
  FieldRow label_row;
  protected ArrayList<DataFieldRow> data_rows = new ArrayList<DataFieldRow>();

  public abstract void populate ();

  construct {
    this.set_orientation (Orientation.VERTICAL);

    label_row = new FieldRow (sheet.pane.row_group);
    this.add (label_row);
    label_row.pack_label (label_name);
  }

  public void add_to_sheet () {
    if (!added) {
      sheet.attach (this, 0, row_nr, 1, 1);
      added = true;
    }
  }

  public void remove_from_sheet () {
    if (added) {
      sheet.remove (this);
      added = false;
    }
  }

  public bool reads_param (string param) {
    return param == property_name;
  }

  public bool is_empty () {
    return get_children ().length () == 1;
  }

  public void clear () {
    foreach (var row in data_rows) {
      row.destroy ();
    }
    data_rows.clear ();
  }

  public void add_row (DataFieldRow row) {
    this.add (row);
    data_rows.add (row);

    row.set_can_focus (true);
    row.clicked.connect( () => {
	sheet.pane.enter_edit_mode (row);
      });

    row.update ();
  }

  public void remove_row (DataFieldRow row) {
    this.remove (row);
    data_rows.remove (row);
  }

  public virtual Value? get_value () {
    return null;
  }

  public void save () {
    var value = get_value ();
    if (value == null)
      warning ("Unimplemented get_value()");
    else {
      saving = true;
      sheet.pane.contact.set_persona_property.begin (sheet.persona, property_name, value,
						     (obj, result) => {
	  try {
	    var contact = obj as Contact;
	    contact.set_persona_property.end (result);
	    saving = false;
	  } catch (PropertyError e1) {
	    warning ("Unable to edit property '%s': %s", property_name, e1.message);
	  } catch (Error e2) {
	    warning ("Unable to create writeable persona: %s", e2.message);
	  }

						     });
    }
  }
}

public abstract class Contacts.DataFieldRow : FieldRow {
  public FieldSet field_set;
  ulong set_focus_child_id;

  public DataFieldRow (FieldSet field_set) {
    base (field_set.sheet.pane.row_group);
    this.field_set = field_set;
  }
  public abstract void update ();
  public virtual void pack_edit_widgets () {
  }
  public virtual bool finish_edit_widgets (bool save) {
    return false;
  }

  public void enter_edit_mode () {
    this.set_can_focus (false);
    foreach (var w in this.get_children ()) {
      w.hide ();
      w.set_data ("original-widget", true);
    }

    this.reset ();
    this.pack_edit_widgets ();
    var b = this.pack_delete_button ();
    b.clicked.connect ( () => {
	field_set.remove_row (this);
	field_set.save ();
      });

    foreach (var w in this.get_children ()) {
      if (!w.get_data<bool> ("original-widget"))
	w.show_all ();
    }

    var parent_container = (this.get_parent () as Container);
    var pane = field_set.sheet.pane;
    var row = this;
    set_focus_child_id = parent_container.set_focus_child.connect ( (widget) => {
	if (parent_container.get_focus_child () != row) {
	  Idle.add(() => {
	      if (pane.editing_row == row)
		pane.exit_edit_mode (true);
	      return false;
	    });
	}
      });
  }

  public void exit_edit_mode (bool save) {
    var parent_container = (this.get_parent () as Container);
    parent_container.disconnect (set_focus_child_id);

    var changed = finish_edit_widgets (save);

    foreach (var w in this.get_children ()) {
      if (!w.get_data<bool> ("original-widget"))
	w.destroy ();
    }

    update ();
    this.show_all ();
    this.set_can_focus (true);

    if (save && changed)
      field_set.save ();
  }

  public void setup_entry_for_edit (Entry entry, bool grab_focus = true) {
    if (grab_focus) {
      ulong id = 0;
      id = entry.size_allocate.connect ( () => {
	  entry.grab_focus ();
	  entry.disconnect (id);
	});
    }
    entry.activate.connect ( () => {
	field_set.sheet.pane.exit_edit_mode (true);
      });
    entry.key_press_event.connect ( (key_event) => {
	if (key_event.keyval == Gdk.keyval_from_name ("Escape")) {
	  field_set.sheet.pane.exit_edit_mode (false);
	}
	return false;
      });
  }
}

class Contacts.LinkFieldRow : DataFieldRow {
  public UrlFieldDetails details;
  Label text_label;
  LinkButton uri_button;
  Entry? entry;

  public LinkFieldRow (FieldSet field_set, UrlFieldDetails details) {
    base (field_set);
    this.details = details;

    text_label = this.pack_text ();
    var image = new Image.from_icon_name ("web-browser" /* -symbolic */, IconSize.MENU);
    image.get_style_context ().add_class ("dim-label");
    uri_button = new LinkButton("");
    uri_button.remove (uri_button.get_child ());
    uri_button.set_relief (ReliefStyle.NONE);
    uri_button.add (image);
    this.right_add (uri_button);
  }

  public override void update () {
    text_label.set_text (Contact.format_uri_link_text (details));
    uri_button.set_uri (details.value);
  }

  public override void pack_edit_widgets () {
    entry = this.pack_entry (details.value);
    setup_entry_for_edit (entry);
  }

  public override bool finish_edit_widgets (bool save) {
    var old_details = details;
    var changed = entry.get_text () != details.value;
    if (save && changed)
      details = new UrlFieldDetails (entry.get_text (), old_details.parameters);
    entry = null;
    return changed;
  }
}

class Contacts.LinkFieldSet : FieldSet {
  class construct {
    label_name = _("Links");
    property_name = "urls";
  }

  public override void populate () {
    var details = sheet.persona as UrlDetails;
    if (details == null)
      return;

    var urls = details.urls;
    foreach (var url_details in urls) {
      var row = new LinkFieldRow (this, url_details);
      add_row (row);
    }
  }
  public override Value? get_value () {
    var details = sheet.persona as UrlDetails;
    if (details == null)
      return null;

    var new_details = new HashSet<UrlFieldDetails>();
    foreach (var row in data_rows) {
      var link_row = row as LinkFieldRow;
      new_details.add (link_row.details);
    }

    var value = Value(new_details.get_type ());
    value.set_object (new_details);

    return value;
  }
}

class Contacts.EmailFieldRow : DataFieldRow {
  public EmailFieldDetails details;
  Label text_label;
  Label detail_label;
  Entry? entry;
  TypeCombo? combo;

  public EmailFieldRow (FieldSet field_set, EmailFieldDetails details) {
    base (field_set);
    this.details = details;
    this.pack_text_detail (out text_label, out detail_label);
  }

  public override void update () {
    text_label.set_text (details.value);
    detail_label.set_text (TypeSet.general.format_type (details));
  }

  public override void pack_edit_widgets () {
    this.pack_entry_detail_combo (details.value, details, TypeSet.general, out entry, out combo);
    setup_entry_for_edit (entry);
  }

  public override bool finish_edit_widgets (bool save) {
    var old_details = details;
    bool changed = details.value != entry.get_text () || combo.modified;
    if (save && changed) {
      details = new EmailFieldDetails (entry.get_text (), old_details.parameters);
      combo.update_details (details);
    }
    entry = null;
    combo = null;
    return changed;
  }
}

class Contacts.EmailFieldSet : FieldSet {
  class construct {
    label_name = _("Email");
    property_name = "email-addresses";
  }

  public override void populate () {
    var details = sheet.persona as EmailDetails;
    if (details == null)
      return;
    var emails = Contact.sort_fields<EmailFieldDetails>(details.email_addresses);
    foreach (var email in emails) {
      var row = new EmailFieldRow (this, email);
      add_row (row);
    }
  }
  public override Value? get_value () {
    var details = sheet.persona as EmailDetails;
    if (details == null)
      return null;

    var new_details = new HashSet<EmailFieldDetails>();
    foreach (var row in data_rows) {
      var email_row = row as EmailFieldRow;
      new_details.add (email_row.details);
    }

    var value = Value(new_details.get_type ());
    value.set_object (new_details);

    return value;
  }
}

class Contacts.PhoneFieldRow : DataFieldRow {
  PhoneFieldDetails details;
  Label text_label;
  Label detail_label;

  public PhoneFieldRow (FieldSet field_set, PhoneFieldDetails details) {
    base (field_set);
    this.details = details;
    this.pack_text_detail (out text_label, out detail_label);
  }

  public override void update () {
    text_label.set_text (details.value);
    detail_label.set_text (TypeSet.phone.format_type (details));
  }
}

class Contacts.PhoneFieldSet : FieldSet {
  class construct {
    label_name = _("Phone");
    property_name = "phone-numbers";
  }
  public override void populate () {
    var details = sheet.persona as PhoneDetails;
    if (details == null)
      return;
    var phone_numbers = Contact.sort_fields<PhoneFieldDetails>(details.phone_numbers);
    foreach (var phone in phone_numbers) {
      var row = new PhoneFieldRow (this, phone);
      add_row (row);
    }
  }
}

class Contacts.ChatFieldRow : DataFieldRow {
  string protocol;
  ImFieldDetails details;

  Label text_label;

  public ChatFieldRow (FieldSet field_set, string protocol, ImFieldDetails details) {
    base (field_set);
    this.protocol = protocol;
    this.details = details;
    text_label = this.pack_text ();
  }

  public override void update () {
    var im_persona = field_set.sheet.persona as Tpf.Persona;
    text_label.set_text (Contact.format_im_name (im_persona, protocol, details.value));
  }
}

class Contacts.ChatFieldSet : FieldSet {
  class construct {
    label_name = _("Chat");
    property_name = "im-addresses";
  }
  public override void populate () {
    var details = sheet.persona as ImDetails;
    if (details == null)
      return;
    foreach (var protocol in details.im_addresses.get_keys ()) {
      foreach (var id in details.im_addresses[protocol]) {
	if (sheet.persona is Tpf.Persona) {
	  var row = new ChatFieldRow (this, protocol, id);
	  add_row (row);
	}
      }
    }
  }
}

class Contacts.BirthdayFieldRow : DataFieldRow {
  BirthdayDetails details;
  Label text_label;

  public BirthdayFieldRow (FieldSet field_set, BirthdayDetails details) {
    base (field_set);
    this.details = details;

    text_label = this.pack_text ();
    var image = new Image.from_icon_name ("preferences-system-date-and-time-symbolic", IconSize.MENU);
    image.get_style_context ().add_class ("dim-label");
    var button = new Button();
    button.set_relief (ReliefStyle.NONE);
    button.add (image);
    this.right_add (button);
  }

  public override void update () {
    DateTime? bday = details.birthday;
    text_label.set_text (bday.to_local ().format ("%x"));
  }
}

class Contacts.BirthdayFieldSet : FieldSet {
  class construct {
    label_name = _("Birthday");
    property_name = "birthday";
  }
  public override void populate () {
    var details = sheet.persona as BirthdayDetails;
    if (details == null)
      return;

    DateTime? bday = details.birthday;
    if (bday != null) {
      var row = new BirthdayFieldRow (this, details);
      add_row (row);
    }
  }
}

class Contacts.NicknameFieldRow : DataFieldRow {
  string nickname;
  Label text_label;

  public NicknameFieldRow (FieldSet field_set, string nickname) {
    base (field_set);
    this.nickname = nickname;

    text_label = this.pack_text ();
  }

  public override void update () {
    text_label.set_text (nickname);
  }
}

class Contacts.NicknameFieldSet : FieldSet {
  class construct {
    label_name = _("Nickname");
    property_name = "nickname";
  }
  public override void populate () {
    var details = sheet.persona as NameDetails;
    if (details == null)
      return;

    if (is_set (details.nickname)) {
      var row = new NicknameFieldRow (this, details.nickname);
      add_row (row);
    }
  }
}

class Contacts.NoteFieldRow : DataFieldRow {
  NoteFieldDetails details;
  Label text_label;

  public NoteFieldRow (FieldSet field_set, NoteFieldDetails details) {
    base (field_set);
    this.details = details;

    text_label = this.pack_text (true);
  }

  public override void update () {
    text_label.set_text (details.value);
  }
}

class Contacts.NoteFieldSet : FieldSet {
  class construct {
    label_name = _("Note");
    property_name = "notes";
  }
  public override void populate () {
    var details = sheet.persona as NoteDetails;
    if (details == null)
      return;

    foreach (var note in details.notes) {
      var row = new NoteFieldRow (this, note);
      add_row (row);
    }
  }
}

class Contacts.AddressFieldRow : DataFieldRow {
  PostalAddressFieldDetails details;
  Label? text_label[8];
  Label detail_label;

  public AddressFieldRow (FieldSet field_set, PostalAddressFieldDetails details) {
    base (field_set);
    this.details = details;
    this.pack_text_detail (out text_label[0], out detail_label);
    for (int i = 1; i < text_label.length; i++) {
      text_label[i] = this.pack_text (true);
    }
  }

  public override void update () {
    detail_label.set_text (TypeSet.general.format_type (details));

    string[] strs = Contact.format_address (details.value);
    for (int i = 0; i < text_label.length; i++) {
      if (i < strs.length && strs[i] != null) {
	text_label[i].set_text (strs[i]);
	text_label[i].show ();
	text_label[i].set_no_show_all (false);
      } else {
	text_label[i].hide ();
	text_label[i].set_no_show_all (true);
      }
    }
  }
}

class Contacts.AddressFieldSet : FieldSet {
  class construct {
    label_name = _("Addresses");
    property_name = "postal-addresses";
  }
  public override void populate () {
    var details = sheet.persona as PostalAddressDetails;
    if (details == null)
      return;

    foreach (var addr in details.postal_addresses) {
      var row = new AddressFieldRow (this, addr);
      add_row (row);
    }
  }
}

public class Contacts.PersonaSheet : Grid {
  public ContactPane pane;
  public Persona persona;
  FieldRow header;
  FieldRow footer;

  static Type[] field_set_types = {
    typeof(LinkFieldSet),
    typeof(EmailFieldSet),
    typeof(PhoneFieldSet),
    typeof(ChatFieldSet),
    typeof(BirthdayFieldSet),
    typeof(NicknameFieldSet),
    typeof(AddressFieldSet),
    typeof(NoteFieldSet)
    /* More:
       company/department/profession/title/manager/assistant
    */
  };
  FieldSet? field_sets[8]; // This is really the size of field_set_types

  public PersonaSheet(ContactPane pane, Persona persona) {
    assert (field_sets.length == field_set_types.length);

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

      header.pack_header (Contact.format_persona_store_name (persona.store));

      if (!editable) {
	var image = new Image.from_icon_name ("changes-prevent-symbolic", IconSize.MENU);

	image.get_style_context ().add_class ("dim-label");
	image.set_valign (Align.CENTER);
	header.left_add (image);
      }
    }

    for (int i = 0; i < field_set_types.length; i++) {
      var field_set = (FieldSet) Object.new(field_set_types[i], sheet: this, row_nr: row_nr++);
      field_sets[i] = field_set;

      field_set.populate ();
      if (!field_set.is_empty ())
	field_set.add_to_sheet ();
    }

    if (editable) {
      footer = new FieldRow (pane.row_group);
      this.attach (footer, 0, row_nr++, 1, 1);

      var b = new Button.with_label ("Add detail...");
      b.set_halign (Align.START);

      footer.pack (b);
    }

    persona.notify.connect(persona_notify_cb);
  }

  ~PersonaSheet() {
    persona.notify.disconnect(persona_notify_cb);
  }

  private void persona_notify_cb (ParamSpec pspec) {
    var name = pspec.get_name ();
    foreach (var field_set in field_sets) {
      if (field_set.reads_param (name) && !field_set.saving) {
	field_set.clear ();
	field_set.populate ();

	if (field_set.is_empty ())
	  field_set.remove_from_sheet ();
	else {
	  field_set.show_all ();
	  field_set.add_to_sheet ();
	}
      }
    }
  }
}


public class Contacts.ContactPane : ScrolledWindow {
  private Store contacts_store;
  private Grid top_grid;
  private Grid card_grid;
  private Grid personas_grid;
  public RowGroup row_group;
  public DataFieldRow? editing_row;

  public Contact? contact;

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
    if (contact != null)
      contact.personas_changed.disconnect (personas_changed_cb);

    contact = new_contact;

    update_card ();
    update_personas ();

    if (contact != null)
      contact.personas_changed.connect (personas_changed_cb);
  }

  private void personas_changed_cb (Contact contact) {
    update_personas ();
  }

  public void new_contact (ListPane list_pane) {
  }

  public void enter_edit_mode (DataFieldRow row) {
    if (editing_row != row) {
      exit_edit_mode (true);
      editing_row = row;
      editing_row.enter_edit_mode ();
    }
  }

  public void exit_edit_mode (bool save) {
    if (editing_row != null)
      editing_row.exit_edit_mode (save);
    editing_row = null;
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
    top_grid.set_margin_top (10);
    top_grid.set_margin_bottom (10);
    top_grid.set_row_spacing (20);
    this.add_with_viewport (top_grid);
    top_grid.set_focus_vadjustment (this.get_vadjustment ());

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
