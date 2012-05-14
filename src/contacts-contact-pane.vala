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

public class Contacts.FieldRow : Contacts.Row {
  Clickable clickable;
  int start;
  bool has_child_focus;
  ContactPane pane;

  /* show_as_editable means we prelight, can_focus, show selected, etc.
     It doesn't mean we can't edit the row. For instance the
     Card row is editing when we're editing the full name, but
     thats not represented in the UI as editing the row. */
  protected bool show_as_editable;
  protected bool is_editing;

  public FieldRow(RowGroup group, ContactPane pane) {
    base (group);
    this.pane = pane;
    set_redraw_on_allocate (true); // Since we draw the focus rect

    this.button_press_event.connect ( (ev) => {
	if (!is_editing)
	  this.pane.exit_edit_mode (true);
	return false;
      });

    clickable = new Clickable (this);
    clickable.set_focus_on_click (true);
    clickable.clicked.connect ( () => { this.clicked (); } );
    start = 0;

    /* This should really be in class construct, but that doesn't seem to work... */
    activate_signal = GLib.Signal.lookup ("activate-row", typeof (FieldRow));
  }

  public void set_editing (bool val) {
    is_editing = val;
  }

  public void reset () {
    start = 0;
  }

  public signal void clicked ();

  public override bool focus (DirectionType direction) {
    var row_can_focus = get_can_focus ();

    /* Non-focusable rows get the standard behvaiour */
    if (!row_can_focus)
      return base.focus (direction);

    /* Focusable rows have to also support focusable children,
       which is not supported by Container.focus(), so we
       work around that. */

    bool res = false;

    bool recurse_into = false;
    if (has_focus) {
      switch (direction) {
      case DirectionType.RIGHT:
      case DirectionType.TAB_FORWARD:
	recurse_into = true;
	break;
      }
    } else if (this.get_focus_child () != null) {
      recurse_into = true;
    } else {
      switch (direction) {
      case DirectionType.LEFT:
      case DirectionType.TAB_BACKWARD:
	recurse_into = true;
	break;
      }
    }

    if (recurse_into) {
      set_can_focus (false);
      res = base.focus (direction);
      set_can_focus (true);

      if (!res && !has_focus) {
	switch (direction) {
	case DirectionType.LEFT:
	case DirectionType.TAB_BACKWARD:
	  this.grab_focus ();
	  res = true;
	  break;
	}
      }
    } else {
      if (!has_focus) {
	this.grab_focus ();
	res = true;
      }
    }

    return res;
  }

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
    clickable.unrealize ();
  }

  public override bool draw (Cairo.Context cr) {
    Allocation allocation;
    this.get_allocation (out allocation);

    var context = this.get_style_context ();

    context.save ();
    StateFlags state = 0;
    if (show_as_editable) {
      state = clickable.state & (StateFlags.ACTIVE | StateFlags.PRELIGHT);
      if (is_editing)
	state |= StateFlags.SELECTED;
    }
    context.set_state (state);
    if (state != 0)
      context.render_background (cr,
				 0, 0, allocation.width, allocation.height);

    if (this.has_visible_focus ())
      context.render_focus (cr, 0, 0, allocation.width, allocation.height);

    context.restore ();

    base.draw (cr);

    return true;
  }

  public override void parent_set (Widget? old_parent) {
    if (old_parent != null) {
      var old_parent_container = (old_parent as Container);
      old_parent_container.set_focus_child.disconnect (parent_set_focus_child);
    }

    var parent_container = (this.get_parent () as Container);
    has_child_focus = parent_container != null && parent_container.get_focus_child () == this;
    if (parent_container != null)
      parent_container.set_focus_child.connect (parent_set_focus_child);
  }

  public virtual signal void lost_child_focus () {
  }

  public void parent_set_focus_child (Container container, Widget? widget) {
    var old_has_child_focus = has_child_focus;
    has_child_focus = widget == this;

    if (old_has_child_focus && !has_child_focus) {
	  Idle.add(() => {
	      if (!has_child_focus)
		lost_child_focus ();
	      return false;
	    });
    }
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
      Markup.printf_escaped ("<span font='24px'>%s</span>", s));
    l.set_halign (Align.START);
    pack (l);
  }

  public Grid pack_header_in_grid (string s, out Label label) {
    var grid = new Grid ();
    grid.set_column_spacing (4);
    var l = new Label (s);
    label = l;
    l.set_markup (
      Markup.printf_escaped ("<span font='24px'>%s</span>", s));
    l.set_halign (Align.START);
    l.set_hexpand (true);

    grid.set_halign (Align.FILL);
    grid.add (l);

    pack (grid);

    return grid;
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

  public void pack_widget_detail_combo (Widget w, AbstractFieldDetails detail, TypeSet type_set, out TypeCombo combo) {
    var grid = new Grid ();
    grid.set_column_spacing (16);

    grid.add (w);

    combo = new TypeCombo (type_set);
    combo.set_hexpand (false);
    combo.set_halign (Align.END);
    combo.set_active (detail);

    grid.set_halign (Align.FILL);
    grid.add (combo);

    pack (grid);
  }


  public void pack_entry_detail_combo (string text, AbstractFieldDetails detail, TypeSet type_set, out Entry entry, out TypeCombo combo) {
    entry = new Entry ();
    entry.get_style_context ().add_class ("contacts-entry");
    entry.set_text (text);
    entry.set_hexpand (true);
    entry.set_halign (Align.FILL);

    pack_widget_detail_combo (entry, detail, type_set, out combo);
  }

  public Entry pack_entry (string s) {
    var e = new Entry ();
    e.get_style_context ().add_class ("contacts-entry");
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


  public virtual signal bool enter_edit_mode () {
    return false;
  }

  public virtual signal void exit_edit_mode (bool save) {
  }
}

public abstract class Contacts.FieldSet : Grid {
  public class string label_name;
  public class string detail_name;
  public class string property_name;
  public class bool is_single_value;

  public PersonaSheet sheet { get; construct; }
  public int row_nr { get; construct; }
  public bool added;
  public bool saving;
  FieldRow label_row;
  protected ArrayList<DataFieldRow> data_rows = new ArrayList<DataFieldRow>();

  public abstract void populate ();
  public abstract DataFieldRow new_field ();

  construct {
    this.set_orientation (Orientation.VERTICAL);

    label_row = new FieldRow (sheet.pane.row_group, sheet.pane);
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
	    saving = false;
	    contact.set_persona_property.end (result);
	  } catch (Error e2) {
	    App.app.show_message (e2.message);
	    refresh_from_persona ();
	  }
						     });
    }
  }

  public void refresh_from_persona () {
    this.clear ();
    this.populate ();

    if (this.is_empty ())
      this.remove_from_sheet ();
    else {
      this.show_all ();
      this.add_to_sheet ();
    }
  }
}

public abstract class Contacts.DataFieldRow : FieldRow {
  public FieldSet field_set;
  protected Button? delete_button;

  public DataFieldRow (FieldSet field_set) {
    base (field_set.sheet.pane.row_group, field_set.sheet.pane);
    bool editable =
      Contact.persona_has_writable_property (field_set.sheet.persona,
					     field_set.property_name);
    set_editable (editable);
    this.field_set = field_set;
  }

  public void set_editable (bool editable) {
    this.show_as_editable = editable;
    set_can_focus (editable);
  }

  public abstract void update ();
  public virtual void pack_edit_widgets () {
  }
  public virtual bool finish_edit_widgets (bool save) {
    return false;
  }

  public override bool enter_edit_mode () {
    if (!show_as_editable)
      return false;

    this.set_can_focus (false);
    foreach (var w in this.get_children ()) {
      w.hide ();
      w.set_data ("original-widget", true);
    }

    this.reset ();
    delete_button = this.pack_delete_button ();
    delete_button.clicked.connect ( () => {
	field_set.remove_row (this);
	field_set.save ();
      });

    this.pack_edit_widgets ();

    foreach (var w in this.get_children ()) {
      if (!w.get_data<bool> ("original-widget"))
	w.show_all ();
    }

    return true;
  }

  public override void lost_child_focus () {
    if (field_set.sheet.pane.editing_row == this)
      field_set.sheet.pane.exit_edit_mode (true);
  }

  public override void exit_edit_mode (bool save) {
    if (!show_as_editable)
      return;

    var had_child_focus = this.get_focus_child () != null;

    var changed = finish_edit_widgets (save);

    delete_button = null;
    foreach (var w in this.get_children ()) {
      if (!w.get_data<bool> ("original-widget"))
	w.destroy ();
    }

    update ();
    this.show_all ();
    this.set_can_focus (true);
    if (had_child_focus)
      this.grab_focus ();

    if (save && changed)
      field_set.save ();
  }

  public void setup_entry_for_edit (Entry entry, bool grab_focus = true) {
    if (grab_focus) {
      Utils.grab_widget_later (entry);
    }
    entry.activate.connect_after ( () => {
	field_set.sheet.pane.exit_edit_mode (true);
      });
    entry.key_press_event.connect ( (key_event) => {
	if (key_event.keyval == Gdk.Key.Escape) {
	  field_set.sheet.pane.exit_edit_mode (false);
	}
	return false;
      });
  }

  public void setup_text_view_for_edit (TextView text, bool grab_focus = true) {
    if (grab_focus) {
      Utils.grab_widget_later (text);
    }
    text.key_press_event.connect ( (key_event) => {
	if (key_event.keyval == Gdk.Key.Escape) {
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
    var image = new Image.from_icon_name ("web-browser-symbolic", IconSize.MENU);
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
    label_name = C_("Addresses on the Web", "Links");
    detail_name = C_("Web address", "Link");
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

  public override DataFieldRow new_field () {
    var row = new LinkFieldRow (this, new UrlFieldDetails (""));
    add_row (row);
    return row;
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

class Contacts.DetailedFieldRow<T> : DataFieldRow {
  public AbstractFieldDetails<string> _details;
  TypeSet type_set;
  Label text_label;
  Label detail_label;
  Entry? entry;
  TypeCombo? combo;

  public delegate AbstractFieldDetails<string> DataCreate(string s);
  DataCreate data_create;

  public T details { get { return (T)_details; } }

  public DetailedFieldRow (FieldSet field_set, AbstractFieldDetails<string> details, TypeSet type_set, owned DataCreate data_create) {
    base (field_set);
    this._details = details;
    this.type_set = type_set;
    this.data_create = (owned) data_create;
    this.pack_text_detail (out text_label, out detail_label);
  }

  public override void update () {
    text_label.set_text (_details.value);
    detail_label.set_text (type_set.format_type (_details));
  }

  public override void pack_edit_widgets () {
    this.pack_entry_detail_combo (_details.value, _details, type_set, out entry, out combo);
    setup_entry_for_edit (entry);
  }

  public override bool finish_edit_widgets (bool save) {
    var old_details = _details;
    bool changed = _details.value != entry.get_text () || combo.modified;
    if (save && changed) {
      _details = data_create (entry.get_text ());
      _details.parameters = old_details.parameters;
      combo.update_details (_details);
    }
    entry = null;
    combo = null;
    return changed;
  }
}

class Contacts.EmailFieldSet : FieldSet {
  class construct {
    label_name = _("Email");
    detail_name = _("Email");
    property_name = "email-addresses";
  }

  public override void populate () {
    var details = sheet.persona as EmailDetails;
    if (details == null)
      return;
    var emails = Contact.sort_fields<EmailFieldDetails>(details.email_addresses);
    foreach (var email in emails) {
      var row = new DetailedFieldRow<EmailFieldDetails> (this, email,TypeSet.general, (s) => { return new EmailFieldDetails (s); } );
      add_row (row);
    }
  }

  public override DataFieldRow new_field () {
    var row = new DetailedFieldRow<EmailFieldDetails> (this, new EmailFieldDetails("") ,TypeSet.general, (s) => { return new EmailFieldDetails (s); } );
    add_row (row);
    return row;
  }

  public override Value? get_value () {
    var details = sheet.persona as EmailDetails;
    if (details == null)
      return null;

    var new_details = new HashSet<EmailFieldDetails>();
    foreach (var row in data_rows) {
      var email_row = row as DetailedFieldRow<EmailFieldDetails>;
      new_details.add (email_row.details);
    }

    var value = Value(new_details.get_type ());
    value.set_object (new_details);

    return value;
  }
}

class Contacts.PhoneFieldSet : FieldSet {
  class construct {
    label_name = _("Phone");
    detail_name = _("Phone number");
    property_name = "phone-numbers";
  }
  public override void populate () {
    var details = sheet.persona as PhoneDetails;
    if (details == null)
      return;
    var phone_numbers = Contact.sort_fields<PhoneFieldDetails>(details.phone_numbers);
    foreach (var phone in phone_numbers) {
      var row = new DetailedFieldRow<PhoneFieldDetails> (this, phone,TypeSet.phone, (s) => { return new PhoneFieldDetails (s);} );
      add_row (row);
    }
  }

  public override DataFieldRow new_field () {
    var row = new DetailedFieldRow<PhoneFieldDetails> (this, new PhoneFieldDetails("") ,TypeSet.phone, (s) => { return new EmailFieldDetails (s); } );
    add_row (row);
    return row;
  }

  public override Value? get_value () {
    var details = sheet.persona as PhoneDetails;
    if (details == null)
      return null;

    var new_details = new HashSet<PhoneFieldDetails>();
    foreach (var row in data_rows) {
      var phone_row = row as DetailedFieldRow<PhoneFieldDetails>;
      new_details.add (phone_row.details);
    }

    var value = Value(new_details.get_type ());
    value.set_object (new_details);

    return value;
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
    this.set_editable (false);
  }

  public override void update () {
    var im_persona = field_set.sheet.persona as Tpf.Persona;
    text_label.set_text (Contact.format_im_name (im_persona, protocol, details.value));
  }
}

class Contacts.ChatFieldSet : FieldSet {
  class construct {
    label_name = _("Chat");
    detail_name = _("Chat");
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

  public override DataFieldRow new_field () {
    var row = new ChatFieldRow (this, "", new ImFieldDetails (""));
    add_row (row);
    return row;
  }
}

class Contacts.BirthdayFieldRow : DataFieldRow {
  public DateTime details;
  Label text_label;
  SpinButton? day_spin;
  SpinButton? year_spin;
  ComboBoxText? combo;

  public BirthdayFieldRow (FieldSet field_set, DateTime details) {
    base (field_set);
    this.details = details;

    text_label = this.pack_text ();
    var image = new Image.from_icon_name ("preferences-system-date-and-time-symbolic", IconSize.MENU);
    image.get_style_context ().add_class ("dim-label");
    var button = new Button();
    button.set_relief (ReliefStyle.NONE);
    button.add (image);
    this.right_add (button);
    button.clicked.connect ( () => {
	Utils.show_calendar (details);
      });
  }

  public override void update () {
    text_label.set_text (details.to_local ().format ("%x"));
  }

  public override void pack_edit_widgets () {
    var bday = details.to_local ();
    var grid = new Grid ();
    grid.set_column_spacing (16);

    day_spin = new SpinButton.with_range (0, 31, 1);
    day_spin.set_digits (0);
    day_spin.numeric = true;
    day_spin.set_value ((double)bday.get_day_of_month ());
    grid.add (day_spin);

    setup_entry_for_edit (day_spin);

    combo = new ComboBoxText ();
    combo.append_text (_("January"));
    combo.append_text (_("February"));
    combo.append_text (_("March"));
    combo.append_text (_("April"));
    combo.append_text (_("May"));
    combo.append_text (_("June"));
    combo.append_text (_("July"));
    combo.append_text (_("August"));
    combo.append_text (_("September"));
    combo.append_text (_("October"));
    combo.append_text (_("November"));
    combo.append_text (_("December"));
    combo.set_active (bday.get_month () - 1);
    combo.get_style_context ().add_class ("contacts-combo");
    grid.add (combo);

    year_spin = new SpinButton.with_range (1800, 3000, 1);
    year_spin.set_digits (0);
    year_spin.numeric = true;
    year_spin.set_value ((double)bday.get_year ());
    grid.add (year_spin);

    setup_entry_for_edit (year_spin, false);

    pack (grid);
  }

  public override bool finish_edit_widgets (bool save) {
    var old_details = details;

    var bday = new DateTime.local ((int)year_spin.get_value (),
				   combo.get_active () + 1,
				   (int)day_spin.get_value (),
				   0, 0, 0);
    bday = bday.to_utc ();

    var changed = !bday.equal (old_details);
    if (save && changed)
      details = bday;

    combo = null;
    day_spin = null;
    year_spin = null;
    return changed;
  }
}

class Contacts.BirthdayFieldSet : FieldSet {
  class construct {
    label_name = _("Birthday");
    detail_name = _("Birthday");
    property_name = "birthday";
    is_single_value = true;
  }
  public override void populate () {
    var details = sheet.persona as BirthdayDetails;
    if (details == null)
      return;

    DateTime? bday = details.birthday;
    if (bday != null) {
      var row = new BirthdayFieldRow (this, bday);
      add_row (row);
    }
  }

  public override DataFieldRow new_field () {
    var row = new BirthdayFieldRow (this, new DateTime.now_utc ());
    add_row (row);
    return row;
  }

  public override Value? get_value () {
    var details = sheet.persona as BirthdayDetails;
    if (details == null)
      return null;

    DateTime? new_details = null;
    foreach (var row in data_rows) {
      var bday_row = row as BirthdayFieldRow;
      new_details = bday_row.details;
    }

    var value = Value(typeof (DateTime));
    value.set_boxed (new_details);

    return value;
  }
}

class Contacts.StringFieldRow : DataFieldRow {
  public string value;
  Label text_label;
  Entry? entry;

  public StringFieldRow (FieldSet field_set, string value) {
    base (field_set);
    this.value = value;

    text_label = this.pack_text ();
  }

  public override void update () {
    text_label.set_text (value);
  }

  public override void pack_edit_widgets () {
    entry = this.pack_entry (value);
    setup_entry_for_edit (entry);
  }

  public override bool finish_edit_widgets (bool save) {
    var changed = entry.get_text () != value;
    if (save && changed)
      value = entry.get_text ();
    entry = null;
    return changed;
  }
}

class Contacts.NicknameFieldSet : FieldSet {
  class construct {
    label_name = _("Nickname");
    detail_name = _("Nickname");
    property_name = "nickname";
    is_single_value = true;
  }
  public override void populate () {
    var details = sheet.persona as NameDetails;
    if (details == null)
      return;

    if (is_set (details.nickname)) {
      var row = new StringFieldRow (this, details.nickname);
      add_row (row);
    }
  }

  public override DataFieldRow new_field () {
    var row = new StringFieldRow (this, "");
    add_row (row);
    return row;
  }

  public override Value? get_value () {
    var details = sheet.persona as NameDetails;
    if (details == null)
      return null;

    var value = Value(typeof (string));
    value.set_string ("");
    foreach (var row in data_rows) {
      var string_row = row as StringFieldRow;
      value.set_string (string_row.value);
    }

    return value;
  }
}

class Contacts.NoteFieldRow : DataFieldRow {
  public NoteFieldDetails details;
  Label text_label;
  TextView? text;

  public NoteFieldRow (FieldSet field_set, NoteFieldDetails details) {
    base (field_set);
    this.details = details;

    text_label = this.pack_text (true);
  }

  public override void update () {
    text_label.set_text (details.value);
  }

  public override void pack_edit_widgets () {
    text = new TextView ();
    text.get_style_context ().add_class ("contacts-entry");
    text.set_hexpand (true);
    text.set_vexpand (true);
    var scrolled = new ScrolledWindow (null, null);
    scrolled.set_shadow_type (ShadowType.OUT);
    scrolled.add_with_viewport (text);

    pack (scrolled);

    delete_button.set_valign (Align.START);

    text.get_buffer ().set_text (details.value);
    text.get_buffer ().set_modified (false);

    setup_text_view_for_edit (text);
  }

  public override bool finish_edit_widgets (bool save) {
    var old_details = details;
    var changed = text.get_buffer (). get_modified ();
    if (save && changed) {
	TextIter start, end;
	text.get_buffer ().get_start_iter (out start);
	text.get_buffer ().get_end_iter (out end);
	var value = text.get_buffer ().get_text (start, end, true);
	details = new NoteFieldDetails (value, old_details.parameters);
    }
    text = null;

    return changed;
  }
}

class Contacts.NoteFieldSet : FieldSet {
  class construct {
    label_name = _("Note");
    detail_name = _("Note");
    property_name = "notes";
    is_single_value = true;
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

  public override DataFieldRow new_field () {
    var row = new NoteFieldRow (this, new NoteFieldDetails (""));
    add_row (row);
    return row;
  }

  public override Value? get_value () {
    var details = sheet.persona as NoteDetails;
    if (details == null)
      return null;

    var new_details = new HashSet<NoteFieldDetails>();
    foreach (var row in data_rows) {
      var note_row = row as NoteFieldRow;
      new_details.add (note_row.details);
    }

    var value = Value(new_details.get_type ());
    value.set_object (new_details);

    return value;
  }
}

class Contacts.AddressFieldRow : DataFieldRow {
  public PostalAddressFieldDetails details;
  Label? text_label[8];
  Label detail_label;
  Entry? entry[7];
  TypeCombo? combo;

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

  public override void pack_edit_widgets () {

    var grid = new Box (Orientation.VERTICAL, 0);
    grid.set_hexpand (true);
    grid.set_halign (Align.FILL);

    for (int i = 0; i < entry.length; i++) {
      string postal_part;
      details.value.get (Contact.postal_element_props[i], out postal_part);
      entry[i] = new Entry ();
      entry[i].set_hexpand (true);
      if (postal_part != null)
	entry[i].set_text (postal_part);
      entry[i].set ("placeholder-text", Contact.postal_element_names[i]);
      entry[i].get_style_context ().add_class ("contacts-entry");
      entry[i].get_style_context ().add_class ("contacts-postal-entry");
      grid.add (entry[i]);

      setup_entry_for_edit (entry[i], i == 0);
    }

    this.pack_widget_detail_combo (grid, details, TypeSet.general, out combo);
    delete_button.set_valign (Align.START);
    var size_group = new SizeGroup (SizeGroupMode.VERTICAL);
    size_group.add_widget (delete_button);
    size_group.add_widget (combo);

  }

  public override bool finish_edit_widgets (bool save) {
    var old_details = details;

    bool changed = combo.modified;
    for (int i = 0; i < entry.length; i++) {
      string postal_part;
      details.value.get (Contact.postal_element_props[i], out postal_part);
      if (entry[i].get_text () != postal_part) {
	changed = true;
	break;
      }
    }

    if (save && changed) {
      var new_value = new PostalAddress (details.value.po_box,
					 details.value.extension,
					 details.value.street,
					 details.value.locality,
					 details.value.region,
					 details.value.postal_code,
					 details.value.country,
					 details.value.address_format,
					 details.value.uid);
      for (int i = 0; i < entry.length; i++)
	new_value.set (Contact.postal_element_props[i], entry[i].get_text ());
      details = new PostalAddressFieldDetails(new_value, old_details.parameters);
      combo.update_details (details);
    }

    for (int i = 0; i < entry.length; i++)
      entry[i] = null;
    combo = null;

    return changed;
  }
}

class Contacts.AddressFieldSet : FieldSet {
  class construct {
    label_name = _("Addresses");
    detail_name = _("Address");
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

  public override DataFieldRow new_field () {
    var row = new AddressFieldRow (this,
				   new PostalAddressFieldDetails (
				     new PostalAddress (null,
							null,
							null,
							null,
							null,
							null,
							null,
							null,
							null)));
    add_row (row);
    return row;
  }

  public override Value? get_value () {
    var details = sheet.persona as PostalAddressDetails;
    if (details == null)
      return null;

    var new_details = new HashSet<PostalAddressFieldDetails>();
    foreach (var row in data_rows) {
      var addr_row = row as AddressFieldRow;
      new_details.add (addr_row.details);
    }

    var value = Value(new_details.get_type ());
    value.set_object (new_details);

    return value;
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

  public PersonaSheet(ContactPane pane, Persona persona, int sheet_nr) {
    assert (field_sets.length == field_set_types.length);

    this.pane = pane;
    this.persona = persona;

    this.set_orientation (Orientation.VERTICAL);
    this.set_row_spacing (16);

    int row_nr = 0;

    bool editable = Contact.persona_has_writable_property (persona, "email-addresses") &&
      Contact.persona_has_writable_property (persona, "phone-numbers") &&
      Contact.persona_has_writable_property (persona, "postal-addresses");

    if (!Contact.persona_is_main (persona) || sheet_nr > 0) {
      header = new FieldRow (pane.row_group, pane);

      Label label;
      var grid = header.pack_header_in_grid (Contact.format_persona_store_name_for_contact (persona), out label);

      if (!editable) {
	var image = new Image.from_icon_name ("changes-prevent-symbolic", IconSize.MENU);

	label.set_hexpand (false);
	image.get_style_context ().add_class ("dim-label");
	image.set_hexpand (true);
	image.set_halign (Align.START);
	image.set_valign (Align.CENTER);
	grid.add (image);
      }

      if (sheet_nr == 0) {
	var b = new Button.with_label(_("Add to My Contacts"));
	grid.add (b);

	b.clicked.connect ( () => {
	    link_contacts.begin (pane.contact, null, (obj, result) => {
		link_contacts.end (result);
		/* TODO: Support undo */
	      });
	  });
      } else if (pane.contact.individual.personas.size > 1) {
	var b = new Button.with_label(_("Unlink"));
	grid.add (b);

	b.clicked.connect ( () => {
	    unlink_persona.begin (pane.contact, persona, (obj, result) => {
		unlink_persona.end (result);
		/* TODO: Support undo */
		/* TODO: Ensure we don't get suggestion for this linkage again */
	      });
	  });
      }

      this.attach (header, 0, row_nr++, 1, 1);

      header.clicked.connect ( () => {
	  this.pane.enter_edit_mode (header);
	});
    }

    for (int i = 0; i < field_set_types.length; i++) {
      var field_set = (FieldSet) Object.new(field_set_types[i], sheet: this, row_nr: row_nr++);
      field_sets[i] = field_set;

      field_set.populate ();
      if (!field_set.is_empty ())
	field_set.add_to_sheet ();
    }

    if (editable) {
      footer = new FieldRow (pane.row_group, pane);
      this.attach (footer, 0, row_nr++, 1, 1);

      var b = new Button.with_label (_("Add detail..."));
      b.set_halign (Align.START);
      b.clicked.connect (add_detail);
      footer.pack (b);
    }

    persona.notify.connect(persona_notify_cb);
  }

  ~PersonaSheet() {
    persona.notify.disconnect(persona_notify_cb);
  }

  private void add_detail () {
    pane.exit_edit_mode (true);
    var title = _("Select detail to add to %s").printf (pane.contact.display_name);
    var dialog = new Dialog.with_buttons ("",
					  (Window) pane.get_toplevel (),
					  DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
					  Stock.CANCEL, ResponseType.CANCEL,
					  Stock.OK, ResponseType.OK);

    dialog.set_resizable (false);
    dialog.set_default_response (ResponseType.OK);

    var tree_view = new TreeView ();
    var store = new ListStore (2, typeof (string), typeof (FieldSet));
    tree_view.set_model (store);
    tree_view.set_headers_visible (false);
    tree_view.get_selection ().set_mode (SelectionMode.BROWSE);

    var column = new Gtk.TreeViewColumn ();
    tree_view.append_column (column);

    var renderer = new Gtk.CellRendererText ();
    column.pack_start (renderer, false);
    column.add_attribute (renderer, "text", 0);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_size_request (340, 300);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_shadow_type (ShadowType.IN);
    scrolled.add (tree_view);

    var grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_row_spacing (28);

    var l = new Label (title);
    l.set_halign (Align.START);

    grid.add (l);
    grid.add (scrolled);

    var box = dialog.get_content_area () as Box;
    box.pack_start (grid, true, true, 0);
    grid.set_border_width (6);

    TreeIter iter;

    for (int i = 0; i < field_set_types.length; i++) {
      var field_set = field_sets[i];
      if (!(field_set is ChatFieldSet) &&
	  Contact.persona_has_writable_property (persona, field_set.property_name) &&
	  (field_set.is_empty () || !field_set.is_single_value)) {
	store.append (out iter);
	store.set (iter, 0, field_set.detail_name, 1, field_set);
      }
    }

    dialog.show_all ();
    dialog.response.connect ( (response) => {
	if (response == ResponseType.OK) {
	  FieldSet field_set;
	  TreeIter iter2;

	  if (tree_view.get_selection() .get_selected (null, out iter2)) {
	    store.get (iter2, 1, out field_set);

	    var row = field_set.new_field ();
	    field_set.show_all ();
	    field_set.add_to_sheet ();
	    pane.enter_edit_mode (row);
	  }
	}
	dialog.destroy ();
      });
  }

  private void persona_notify_cb (ParamSpec pspec) {
    var name = pspec.get_name ();
    foreach (var field_set in field_sets) {
      if (field_set.reads_param (name) && !field_set.saving) {
	field_set.refresh_from_persona ();
      }
    }
  }
}


public class Contacts.ContactPane : ScrolledWindow {
  private Store contacts_store;
  private Grid top_grid;
  private FieldRow card_row;
  private Grid card_grid;
  private Grid personas_grid;
  public RowGroup row_group;
  public RowGroup card_row_group;
  public FieldRow? editing_row;

  public Button email_button;
  public Button chat_button;
  public Button call_button;
  public Gtk.Menu context_menu;
  private Gtk.MenuItem link_menu_item;
  private Gtk.MenuItem delete_menu_item;

  public Contact? contact;

  const int PROFILE_SIZE = 128;

 private async Persona? set_persona_property (Persona persona,
					       string property_name,
					       Value value) throws GLib.Error, PropertyError {
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
    this.exit_edit_mode (true);
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

  public void update_card () {
    foreach (var w in card_grid.get_children ()) {
      w.destroy ();
    }

    if (contact == null)
      return;

    var image_frame = new ContactFrame (PROFILE_SIZE, true);
    image_frame.clicked.connect ( () => {
	change_avatar (image_frame);
      });
    contact.keep_widget_uptodate (image_frame,  (w) => {
	(w as ContactFrame).set_image (contact.individual, contact);
      });

    card_grid.attach (image_frame,  0, 0, 1, 3);
    card_grid.set_column_spacing (16);

    var l = new Label (null);
    l.set_hexpand (true);
    l.set_halign (Align.START);
    l.set_valign (Align.START);
    l.set_margin_top (4);
    l.set_ellipsize (Pango.EllipsizeMode.END);
    l.xalign = 0.0f;

    contact.keep_widget_uptodate (l,  (w) => {
	(w as Label).set_markup (Markup.printf_escaped ("<span font='16'>%s</span>", contact.display_name));
      });

    var event_box = new EventBox ();
    event_box.set_margin_top (4);
    event_box.set_margin_bottom (8);
    event_box.set_visible_window (false);

    var clickable = new Clickable (event_box);
    event_box.realize.connect_after ( (event) => {
	Gdk.Window window = null;
	foreach (var win in event_box.get_window ().get_children ()) {
	  Widget *w = null;
	  win.get_user_data (out w);
	  if (w == event_box) {
	    window = win;
	  }
	}
	clickable.realize_for (window);
      });
    event_box.unrealize.connect_after ( (event) => {
	clickable.unrealize ();
      });
    clickable.clicked.connect ( () => {
	this.enter_edit_mode (card_row);
      });

    var id1 = card_row.enter_edit_mode.connect_after ( () => {
	event_box.remove (l);
	var entry = new Entry ();
	entry.set_text (contact.display_name);
	entry.set_hexpand (true);
	entry.show ();
	entry.override_font (Pango.FontDescription.from_string ("16px"));
	event_box.add (entry);
	Utils.grab_widget_later (entry);

	entry.activate.connect_after ( () => {
	    exit_edit_mode (true);
	  });
	entry.key_press_event.connect ( (key_event) => {
	    if (key_event.keyval == Gdk.Key.Escape) {
	      exit_edit_mode (false);
	    }
	    return false;
	  });

	return true;
      });

    var id2 = card_row.exit_edit_mode.connect ( (save) => {
	Entry entry = event_box.get_child () as Entry;
	bool changed = entry.get_text () != contact.display_name;

	if (save && changed) {
	  // Things look better if we update immediately, rather than after the setting has
	  // been applied
	  l.set_markup (Markup.printf_escaped ("<span font='16'>%s</span>", entry.get_text ()));

	  Value v = Value (typeof (string));
	  v.set_string (entry.get_text ());
	  set_individual_property.begin (contact,
					 "full-name", v,
					 (obj, result) => {
					   try {
					     set_individual_property.end (result);
					   } catch (Error e) {
					     App.app.show_message (e.message);
					     l.set_markup (Markup.printf_escaped ("<span font='16'>%s</span>", contact.display_name));
					   }
					 });
	}

	event_box.remove (entry);
	event_box.add (l);
      });

    var id3 = card_row.lost_child_focus.connect ( () => {
	if (editing_row == card_row)
	  exit_edit_mode (true);
      });

    event_box.destroy.connect ( () => {
	card_row.disconnect (id1);
	card_row.disconnect (id2);
	card_row.disconnect (id3);
      });

    event_box.add (l);
    card_grid.attach (event_box,  1, 0, 1, 1);

    var merged_presence = contact.create_merged_presence_widget ();
    merged_presence.set_halign (Align.START);
    merged_presence.set_valign (Align.START);
    merged_presence.set_vexpand (true);
    card_grid.attach (merged_presence,  1, 1, 1, 1);

    var box = new Box (Orientation.HORIZONTAL, 0);
    box.set_margin_bottom (4 + 8);
    box.set_halign (Align.START);

    box.get_style_context ().add_class ("linked");
    box.set_homogeneous (true);
    box.set_halign (Align.FILL);
    var image = new Image.from_icon_name ("mail-unread-symbolic", IconSize.MENU);
    var b = new Button ();
    b.add (image);
    box.pack_start (b, true, true, 0);
    email_button = b;
    email_button.clicked.connect (send_email);

    image = new Image.from_icon_name ("user-available-symbolic", IconSize.MENU);
    b = new Button ();
    b.add (image);
    box.pack_start (b, true, true, 0);
    chat_button = b;
    chat_button.clicked.connect (start_chat);

    image = new Image.from_icon_name ("call-start-symbolic", IconSize.MENU);
    b = new Button ();
    b.add (image);
    box.pack_start (b, true, true, 0);
    call_button = b;
    call_button.clicked.connect (start_call);

    card_grid.attach (box,  1, 2, 1, 1);

    card_grid.show_all ();

    update_buttons ();
  }

  public void update_buttons () {
    if (contact == null)
      return;

    var emails = contact.individual.email_addresses;
    email_button.set_sensitive (!emails.is_empty);

    var ims = contact.individual.im_addresses;
    var im_keys = ims.get_keys ();
    bool found_im = false;
    bool callable = false;
    PresenceType max_presence = 0;
    foreach (var protocol in im_keys) {
      foreach (var id in ims[protocol]) {
	var im_persona = contact.find_im_persona (protocol, id.value);
	if (im_persona != null) {
	  var type = im_persona.presence_type;
	  if (type != PresenceType.UNSET &&
	      type != PresenceType.ERROR &&
	      type != PresenceType.OFFLINE &&
	      type != PresenceType.UNKNOWN) {
	    found_im = true;
	    if (type > max_presence)
	      max_presence = type;
	  }
	}

	if (contact.is_callable (protocol, id.value) != null)
	  callable = true;
      }
    }

    if (contacts_store.can_call) {
      var phones = contact.individual.phone_numbers;
      if (!phones.is_empty)
	callable = true;
    }

    string icon;
    if (found_im)
      icon = Contact.presence_to_icon_symbolic (max_presence);
    else
      icon = "user-available-symbolic";
    (chat_button.get_child () as Image).set_from_icon_name (icon, IconSize.MENU);
    chat_button.set_sensitive (found_im);

    call_button.set_sensitive (callable);
  }

  public signal void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation);

  public void add_suggestion (Contact c) {
    var row = new FieldRow (row_group, this);
    personas_grid.add (row);

    var grid = new Grid ();
    grid.get_style_context ().add_class ("contacts-suggestion");
    grid.set_redraw_on_allocate (true);
    grid.draw.connect ( (cr) => {
	Allocation allocation;
	grid.get_allocation (out allocation);

	var context = grid.get_style_context ();
	context.render_background (cr,
				   0, 0,
				   allocation.width, allocation.height);
	return false;
      });
    row.pack (grid);

    var image_frame = new ContactFrame (Contact.SMALL_AVATAR_SIZE);
    c.keep_widget_uptodate (image_frame,  (w) => {
	(w as ContactFrame).set_image (c.individual, c);
      });
    image_frame.set_hexpand (false);
    grid.attach (image_frame, 0, 0, 1, 2);

    var label = new Label ("");
    if (contact.is_main)
      label.set_markup (Markup.printf_escaped (_("Does %s from %s belong here?"), c.display_name, c.format_persona_stores ()));
    else
      label.set_markup (Markup.printf_escaped (_("Do these details belong to %s?"), c.display_name));
    label.set_valign (Align.START);
    label.set_halign (Align.START);
    label.set_line_wrap (true);
    label.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
    label.set_hexpand (false);
    label.xalign = 0.0f;
    grid.attach (label, 1, 0, 1, 1);

    var bbox = new ButtonBox (Orientation.HORIZONTAL);
    var yes = new Button.with_label (_("Yes"));
    var no = new Button.with_label (_("No"));

    yes.clicked.connect ( () => {
      var linked_contact = c.display_name;
      link_contacts.begin (contact, c, (obj, result) => {
	var operation = link_contacts.end (result);
	this.contacts_linked (null, linked_contact, operation);
      });
      row.destroy ();
    });

    no.clicked.connect ( () => {
	contacts_store.add_no_suggest_link (contact, c);
	/* TODO: Add undo */
	row.destroy ();
      });

    bbox.add (yes);
    bbox.add (no);
    bbox.set_spacing (8);
    bbox.set_halign (Align.END);
    bbox.set_hexpand (true);
    bbox.set_border_width (4);
    grid.attach (bbox, 2, 0, 1, 2);
  }

  private uint update_personas_timeout;
  public void update_personas (bool show_matches = true) {
    if (update_personas_timeout != 0) {
      Source.remove (update_personas_timeout);
      update_personas_timeout = 0;
    }

    foreach (var w in personas_grid.get_children ()) {
      w.destroy ();
    }

    if (contact == null)
      return;

    var personas = contact.get_personas_for_display ();

    int i = 0;
    foreach (var p in personas) {
      var sheet = new PersonaSheet(this, p, i++);
      personas_grid.add (sheet);
    }

    if (show_matches) {
      var matches = contact.store.aggregator.get_potential_matches (contact.individual, MatchResult.HIGH);
      foreach (var ind in matches.keys) {
	var c = Contact.from_individual (ind);
	if (c != null && contact.suggest_link_to (c)) {
	  add_suggestion (c);
	}
      }
    }

    personas_grid.show_all ();
  }

  public void show_contact (Contact? new_contact, bool edit=false, bool show_matches = true) {
    if (contact == new_contact)
      return;

    if (contact != null && editing_row != null)
      exit_edit_mode (true);

    if (contact != null) {
      contact.personas_changed.disconnect (personas_changed_cb);
      contact.changed.disconnect (contact_changed_cb);
    }

    contact = new_contact;

    update_card ();
    update_personas (show_matches);

    if (!show_matches) {
      update_personas_timeout = Gdk.threads_add_timeout (100, () => {
	  update_personas ();
	  return false;
	});
    }

    bool can_remove = false;

    if (contact != null) {
      contact.personas_changed.connect (personas_changed_cb);
      contact.changed.connect (contact_changed_cb);

      can_remove = contact.can_remove_personas ();
    }

    delete_menu_item.set_sensitive (can_remove);
    link_menu_item.set_sensitive (contact != null);
  }

  private void personas_changed_cb (Contact contact) {
    update_personas ();
  }

  private void contact_changed_cb (Contact contact) {
    update_buttons ();
  }

  public void enter_edit_mode (FieldRow row) {
    if (editing_row != row) {
      exit_edit_mode (true);
      editing_row = null;
      if (row.enter_edit_mode ()) {
	editing_row = row;
	editing_row.set_editing (true);
      }
    }
  }

  public void exit_edit_mode (bool save) {
    if (editing_row != null) {
      editing_row.exit_edit_mode (save);
      editing_row.set_editing (false);
    }

    editing_row = null;
  }

  private Dialog pick_one_dialog (string title, TreeModel model, out TreeSelection selection) {
    var dialog = new Dialog.with_buttons (title,
					  (Window) this.get_toplevel (),
					  DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
					  Stock.CANCEL, ResponseType.CANCEL,
					  Stock.OK, ResponseType.OK);

    dialog.set_resizable (false);
    dialog.set_default_response (ResponseType.OK);

    var tree_view = new TreeView ();
    tree_view.set_model (model);
    tree_view.set_headers_visible (false);
    tree_view.get_selection ().set_mode (SelectionMode.BROWSE);

    var column = new Gtk.TreeViewColumn ();
    tree_view.append_column (column);

    var renderer = new Gtk.CellRendererText ();
    column.pack_start (renderer, false);
    column.add_attribute (renderer, "text", 0);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_size_request (340, 300);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_shadow_type (ShadowType.IN);
    scrolled.add (tree_view);

    var grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_row_spacing (6);

    var l = new Label (title);
    l.set_halign (Align.START);

    grid.add (l);
    grid.add (scrolled);

    var box = dialog.get_content_area () as Box;
    box.pack_start (grid, true, true, 0);
    grid.set_border_width (6);

    dialog.show_all ();

    selection = tree_view.get_selection ();
    return dialog;
  }


  public void send_email () {
    var emails = contact.individual.email_addresses;
    if (emails.is_empty)
      return;
    if (emails.size == 1) {
      foreach (var email in emails) {
	var email_addr = email.value;
	Utils.compose_mail (email_addr);
      }
    } else {
      TreeIter iter;

      var store = new ListStore (1, typeof (string));
      foreach (var email in emails) {
	var email_addr = email.value;
	store.append (out iter);
	store.set (iter, 0, email_addr);
      }

      TreeSelection selection;
      var dialog = pick_one_dialog (_("Select email address"), store, out selection);
      dialog.response.connect ( (response) => {
	  if (response == ResponseType.OK) {
	    string email2;
	    TreeIter iter2;

	    if (selection.get_selected (null, out iter2)) {
	      store.get (iter2, 0, out email2);
	      Utils.compose_mail (email2);
	    }
	  }
	  dialog.destroy ();
	});
    }
  }

  struct CallValue {
    string phone_nr;
    string protocol;
    string id;
    string name;
  }

  public void start_call () {
    var ims = contact.individual.im_addresses;
    var im_keys = ims.get_keys ();
    var call_targets = new ArrayList<CallValue?>();
    foreach (var protocol in im_keys) {
      foreach (var id in ims[protocol]) {
	var im_persona = contact.find_im_persona (protocol, id.value);
	if (im_persona != null &&
	    contact.is_callable (protocol, id.value) != null) {
	  var type = im_persona.presence_type;
	  if (type != PresenceType.UNSET &&
	      type != PresenceType.ERROR &&
	      type != PresenceType.OFFLINE &&
	      type != PresenceType.UNKNOWN) {
	    CallValue? value = { null, protocol, id.value, Contact.format_im_name (im_persona, protocol, id.value) };
	    call_targets.add (value);
	  }
	}
      }
    }

    if (contacts_store.can_call) {
      var phones = contact.individual.phone_numbers;
      foreach (var phone in phones) {
	CallValue? value = { phone.value, null, null, phone.value };
	call_targets.add (value);
      }
    }


    if (call_targets.is_empty)
      return;

    if (call_targets.size == 1) {
      foreach (var value in call_targets) {
	if (value.phone_nr != null)
	  Utils.start_call (value.phone_nr, this.contacts_store.calling_accounts);
	else {
	  var account = contact.is_callable (value.protocol, value.id);
	  Utils.start_call_with_account (value.id, account);
	}
      }
    } else {
      var store = new ListStore (2, typeof (string), typeof (CallValue?));
      foreach (var value in call_targets) {
	TreeIter iter;
	store.append (out iter);
	store.set (iter, 0, value.name, 1, value);
      }
      TreeSelection selection;
      var dialog = pick_one_dialog (_("Select what to call"), store, out selection);
      dialog.response.connect ( (response) => {
	  if (response == ResponseType.OK) {
	    CallValue? value2;
	    TreeIter iter2;

	    if (selection.get_selected (null, out iter2)) {
	      store.get (iter2, 1, out value2);
	      if (value2.phone_nr != null)
		Utils.start_call (value2.phone_nr, this.contacts_store.calling_accounts);
	      else {
		var account = contact.is_callable (value2.protocol, value2.id);
		Utils.start_call_with_account (value2.id, account);
	      }
	    }
	  }
	  dialog.destroy ();
	});
    }
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
      var store = new ListStore (2, typeof (string), typeof (ImValue?));
      foreach (var value in online_personas) {
	TreeIter iter;
	store.append (out iter);
	store.set (iter, 0, value.name, 1, value);
      }
      TreeSelection selection;
      var dialog = pick_one_dialog (_("Select chat account"), store, out selection);
      dialog.response.connect ( (response) => {
	  if (response == ResponseType.OK) {
	    ImValue? value2;
	    TreeIter iter2;

	    if (selection.get_selected (null, out iter2)) {
	      store.get (iter2, 1, out value2);
	      Utils.start_chat (contact, value2.protocol, value2.id);
	    }
	  }
	  dialog.destroy ();
	});
    }
  }

  public ContactPane (Store contacts_store) {
    this.get_style_context ().add_class ("contacts-content");
    this.set_shadow_type (ShadowType.IN);

    this.button_press_event.connect ( (e) => {
	exit_edit_mode (true);
	return false;
      });

    this.contacts_store = contacts_store;
    row_group = new RowGroup(3);
    row_group.set_column_min_width (0, 32);
    row_group.set_column_min_width (1, 400);
    row_group.set_column_max_width (1, 480);
    row_group.set_column_min_width (2, 32);
    row_group.set_column_spacing (0, 8);
    row_group.set_column_spacing (1, 8);
    row_group.set_column_priority (1, 1);

    card_row_group = row_group.copy ();
    /* This is kinda lame hardcoding so that the frame inside
       the button aligns with the other rows. It really
       depends on the theme, but there seems no good way to
       do this */
    card_row_group.set_column_spacing (0, 0);

    this.set_hexpand (true);
    this.set_vexpand (true);
    this.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

    top_grid = new Grid ();
    top_grid.set_orientation (Orientation.VERTICAL);
    top_grid.set_margin_top (40);
    top_grid.set_margin_bottom (32);
    top_grid.set_row_spacing (20);
    this.add_with_viewport (top_grid);
    top_grid.set_focus_vadjustment (this.get_vadjustment ());

    var viewport = this.get_child ();
    viewport.button_press_event.connect ( (event) => {
	if (event.button == 3) {
	  context_menu.popup (null, null, null, event.button, event.time);
	  return true;
	}
	return false;
      });

    this.get_child().get_style_context ().add_class ("contacts-main-view");
    this.get_child().get_style_context ().add_class ("view");

    card_row = new FieldRow (card_row_group, this);
    top_grid.add (card_row);
    card_grid = new Grid ();
    card_grid.set_vexpand (false);
    card_row.pack (card_grid);

    personas_grid = new Grid ();
    personas_grid.set_orientation (Orientation.VERTICAL);
    personas_grid.set_row_spacing (40);
    top_grid.add (personas_grid);

    top_grid.show_all ();

    context_menu = new Gtk.Menu ();
    link_menu_item = Utils.add_menu_item (context_menu,_("Add/Remove Linked Contacts..."));
    link_menu_item.activate.connect (link_contact);
    link_menu_item.set_sensitive (false);
    //Utils.add_menu_item (context_menu,_("Send..."));
    delete_menu_item = Utils.add_menu_item (context_menu,_("Delete"));
    delete_menu_item.activate.connect (delete_contact);
    delete_menu_item.set_sensitive (false);
  }

  void link_contact () {
    var dialog = new LinkDialog (contact);
    dialog.contacts_linked.connect ( (main_contact, linked_contact, operation) => {
      this.contacts_linked (main_contact, linked_contact, operation);
    });
    dialog.show_all ();
  }

  public signal void will_delete (Contact contact);

  void delete_contact () {
    if (contact != null) {
      contact.hide ();
      this.will_delete (contact);
    }
  }
}
