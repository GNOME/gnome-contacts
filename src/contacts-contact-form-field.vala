/*
 * Copyright (C) 2018 Niels De Graef <nielsdegraef@gmail.com>
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

/**
 * A PropertyField is an abstraction of the property of a {@link Folks.Persona}.
 */
public abstract class Contacts.PropertyField : Object {

  /**
   * The {@link Folks.Persona} this property belongs to.
   */
  public Persona? persona { get; construct set; default = null; }

  /**
   * The canonical name of this property.
   */
  public unowned string property_name { get; construct set; }

// XXX Do we really need to save this?
  protected PropertyWidget? row { get; private set; }

  /**
   * Each subclass is responsible for creating the necessary UI and
   * incorporating it into the given {@link PropertyWidget}.
   */
  protected abstract void create_widgets (PropertyWidget widget);

  /**
   * Creates a widget that can show the property inside a {@link Gtk.ListBox}.
   */
  public ListBoxRow create_row (SizeGroup label_group,
                                SizeGroup value_group,
                                SizeGroup actions_group) {
    this.row = new PropertyWidget (this, label_group, value_group, actions_group);
    this.row.margin_top = 12;
    this.row.hexpand = true;

    // The subclass is responsible to make the appropriate widgets
    create_widgets (row);

    this.row.show_all ();

    return this.row;
  }
}

public interface Contacts.EditableProperty : PropertyField {

  /* public bool dirty { get; construct set; } */

  // NEEDED FOR NEW CONTACT CREATION
  public abstract Value? create_value ();

  // NEEDED FOR CHANGING EXISTING CONTACTS
  public abstract async void save_changes () throws PropertyError;
}

public class Contacts.PropertyWidget : ListBoxRow {

  private Grid grid = new Grid ();

  private unowned SizeGroup labels_group;
  private unowned SizeGroup values_group;
  private unowned SizeGroup actions_group;

// The parent field
/// XXX maybe only store the persona?
  public weak PropertyField field { get; construct set; }

  construct {
    this.selectable = false;
    this.activatable = false;

    this.grid.column_spacing = 12;
    this.grid.row_spacing = 12;
    this.grid.hexpand = true;
    add (this.grid);
  }

  public PropertyWidget (PropertyField parent, SizeGroup labels, SizeGroup values, SizeGroup actions) {
    Object (field: parent);

    this.labels_group = labels;
    this.values_group = values;
    this.actions_group = actions;
  }

  // Get the latest row number. This might have changed due to e.g. deletion of some row
  private int get_last_row_nr () {
    int last_row = -1;
    foreach (var child in this.grid.get_children ())
      last_row = int.max (last_row, get_child_row (child));

    return last_row;
  }

  // Returns the top-attach child property or -1 if not a child
  public int get_child_row (Widget child) {
    int top_attach = -1;
    this.grid.child_get (child, "top-attach", out top_attach);
    return top_attach;
  }

  public void add_row (Widget label, Widget value, Widget? actions = null) {
    int row_nr = get_last_row_nr () + 1;
    this.grid.attach (label, 0, row_nr);
    this.grid.attach (value, 1, row_nr);
    if (actions != null)
      this.grid.attach (actions, 2, row_nr);

    this.labels_group.add_widget (label);
    this.values_group.add_widget (value);
    if (actions != null)
      this.actions_group.add_widget (actions);
  }

  // Buidler
  // Up next are some
  public Label create_type_label (string? text) {
    var label = new Label (text ?? "");

    label.xalign = 1.0f;
    label.halign = Align.END;
    label.valign = Align.START;
    label.get_style_context ().add_class ("dim-label");

    return label;
  }

  public Label create_value_label (string? text, bool use_markup = false) {
    var label = new Label (text ?? "");
    label.use_markup = use_markup;
    label.set_line_wrap (true);
    label.xalign = 0.0f;
    label.set_halign (Align.START);
    label.set_ellipsize (Pango.EllipsizeMode.END);
    label.wrap_mode = Pango.WrapMode.CHAR;
    label.set_selectable (true);

    return label;
  }

  public Label create_value_link (string text, string url) {
    var link = "<a href=\"%s\">%s</a>".printf (url, text);
    return create_value_label (link, true);
  }

  public Entry create_value_entry (string? text) {
    var value_entry = new Entry ();
    value_entry.text = text;
    value_entry.hexpand = true;

    return value_entry;
  }

  public Widget create_value_textview (string? text) {
    var sw = new ScrolledWindow (null, null);
    sw.shadow_type = ShadowType.OUT;
    sw.set_size_request (-1, 100);

    var value_text = new TextView ();
    value_text.buffer.text = text;
    value_text.hexpand = true;
    sw.add (value_text);

    return sw;
  }

  public Button create_delete_button (string? description) {
    var delete_button = new Button.from_icon_name ("user-trash-symbolic", IconSize.MENU);
    delete_button.valign = Align.START;
    delete_button.get_accessible ().set_name (description);
    delete_button.clicked.connect ((button) => {
        int top_attach;
        this.grid.child_get (delete_button, "top-attach", out top_attach);
        this.grid.remove_row (top_attach);
      });
    return delete_button;
  }
}

public class Contacts.NicknameField : PropertyField {

  protected string nickname = "";

  public NicknameField (Persona persona) {
    Object (
      property_name: "nickname",
      persona: persona
    );

    this.nickname = ((NameDetails) persona).nickname;
  }

  public static bool should_show (Persona persona) {
    unowned NameDetails? details = persona as NameDetails;
    return (details != null && details.nickname != "");
  }

  protected override void create_widgets (PropertyWidget widget) {
    var type_label = row.create_type_label (_("Nickname"));
    var value_label = row.create_value_label (this.nickname);
    widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableNicknameField : NicknameField, EditableProperty {

  public EditableNicknameField (Persona? persona) {
    base (persona);
  }

  public EditableNicknameField.empty () {
    Object (
      property_name: "nickname",
      persona: null
    );
  }

  protected override void create_widgets (PropertyWidget widget) {
    var type_label = row.create_type_label (_("Nickname"));
    var nickname_entry = row.create_value_entry (this.nickname);
    nickname_entry.changed.connect ((editable) => { 
        this.nickname = editable.get_chars ();
      });

    var delete_button = row.create_delete_button (_("Remove nickname"));
    widget.add_row (type_label, nickname_entry, delete_button);
  }

  public Value? create_value () {
    if (this.nickname == "")
      return null;

    var new_value = Value (typeof (string));
    new_value.set_string (this.nickname);
    return new_value;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    yield ((NameDetails) this.persona).change_nickname (this.nickname);
  }
}

public class Contacts.BirthdayField : PropertyField {

  // In local timezone
  protected DateTime birthday;

  public BirthdayField (Persona persona) {
    Object (
      property_name: "birthday",
      persona: persona
    );

    unowned BirthdayDetails details = (BirthdayDetails) persona;
    this.birthday = details.birthday.to_local ();
  }

  public static bool should_show (Persona persona) {
    unowned BirthdayDetails? details = persona as BirthdayDetails;
    return (details != null && details.birthday != null);
  }

  protected override void create_widgets (PropertyWidget widget) {
    var type_label = row.create_type_label (_("Birthday"));
    var value_label = row.create_value_label (this.birthday.format ("%x"));
    widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableBirthdayField : BirthdayField, EditableProperty {

  public EditableBirthdayField (Persona? persona) {
    base (persona);
  }

  public EditableBirthdayField.empty () {
    Object (
      property_name: "birthday",
      persona: null
    );

    this.birthday = new DateTime.now_local ();
  }

  protected override void create_widgets (PropertyWidget widget) {
    var type_label = row.create_type_label (_("Birthday"));
    var birthday_entry = create_date_widget ();
    var delete_button = row.create_delete_button (_("Remove birthday"));
    widget.add_row (type_label, birthday_entry, delete_button);
  }

  private Widget create_date_widget () {
    var box = new Grid ();
    box.column_spacing = 12;

    // Day
    var day_spin = new SpinButton.with_range (1.0, 31.0, 1.0);
    day_spin.set_digits (0);
    day_spin.numeric = true;
    day_spin.set_value (this.birthday.get_day_of_month ());
    box.add (day_spin);

    // Month
    var month_combo = new ComboBoxText ();
    var january = new DateTime.local (1, 1, 1, 1, 1, 1);
    for (int i = 0; i < 12; i++) {
        var month = january.add_months (i);
        month_combo.append_text (month.format ("%B"));
    }
    month_combo.set_active (this.birthday.get_month () - 1);
    month_combo.hexpand = true;
    box.add (month_combo);

    // Year
    var year_spin = new SpinButton.with_range (1800, 3000, 1);
    year_spin.set_digits (0);
    year_spin.numeric = true;
    year_spin.set_value (this.birthday.get_year ());
    box.add (year_spin);

    // We can't set the day/month/year directly, so calculate the diff and add that
    day_spin.changed.connect (() => {
        var diff = day_spin.get_value_as_int () - this.birthday.get_day_of_month ();
        this.birthday = this.birthday.add_days (diff);
      });
    month_combo.changed.connect (() => {
        adjust_date_range (year_spin, month_combo, day_spin);

        var diff = (month_combo.get_active () + 1) - this.birthday.get_month ();
        this.birthday = this.birthday.add_months (diff);
      });
    year_spin.changed.connect (() => {
        adjust_date_range (year_spin, month_combo, day_spin);

        var diff = year_spin.get_value_as_int () - this.birthday.get_year ();
        this.birthday = this.birthday.add_years (diff);
      });

    return box;
  }

  // Make sure our user can't make an invalid date (e.g. February 31)
  private void adjust_date_range (SpinButton year_spin, ComboBoxText month_combo, SpinButton day_spin) {
    const int[] month_of_31 = {3, 5, 8, 10};
    if (month_combo.get_active () in month_of_31) {
      day_spin.set_range (1, 30);
    } else if (month_combo.get_active () == 1) {
      var year = (DateYear) year_spin.get_value_as_int ();
      var nr_days = year.is_leap_year ()? 29 : 28;
      day_spin.set_range (1, nr_days);
    }
  }

  public Value? create_value () {
    var new_value = Value (typeof (DateTime));
    new_value.set_boxed (this.birthday.to_utc ());
    return new_value;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    yield ((BirthdayDetails) this.persona).change_birthday (this.birthday);
  }
}

public class Contacts.PhoneNrsField : PropertyField {

  protected ArrayList<string> types = new ArrayList<string> ();
  protected ArrayList<string> phone_nrs = new ArrayList<string> ();

  public PhoneNrsField (Persona persona) {
    Object (
      property_name: "phone-numbers",
      persona: persona
    );

    unowned PhoneDetails? details = this.persona as PhoneDetails;
    foreach (var phone in details.phone_numbers) {
      this.types.add (TypeSet.phone.format_type (phone));
      this.phone_nrs.add (phone.value);
    }
  }

  public static bool should_show (Persona persona) {
    unowned PhoneDetails? details = persona as PhoneDetails;
    return (details != null && !details.phone_numbers.is_empty);
  }

  protected override void create_widgets (PropertyWidget widget) {
    for (int i = 0; i < this.phone_nrs.size; i++)
      add_field (this.types.get(i), this.phone_nrs.get(i), widget);
  }

  protected virtual void add_field (string type, string phone, PropertyWidget widget) {
    var type_label = row.create_type_label (type);
    var value_label = row.create_value_label (phone);
    widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditablePhoneNrsField : PhoneNrsField, EditableProperty {

  public EditablePhoneNrsField (Persona? persona) {
    base (persona);
  }

  public EditablePhoneNrsField.empty () {
    Object (
      property_name: "phone-numbers",
      persona: null
    );

    this.types.add ("");
    this.phone_nrs.add ("");
  }

  protected override void add_field (string type, string phone, PropertyWidget widget) {
    var type_label = row.create_type_label (type);

    var entry = row.create_value_entry (phone);
    entry.changed.connect ((editable) => {
        var row_nr = row.get_child_row ((Widget) editable);
        this.phone_nrs[row_nr] = editable.get_chars ();
      });

    var delete_button = row.create_delete_button (_("Remove phone number"));

    widget.add_row (type_label, entry, delete_button);
  }

  public Value? create_value () {
    if (this.phone_nrs.is_empty)
      return null;

    var new_details = create_set ();
    // Check if we only had empty phone_nrs
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_addrs = create_set ();
    yield ((PhoneDetails) this.persona).change_phone_numbers (new_addrs);
  }

  private HashSet<PhoneFieldDetails>? create_set () {
    var new_details = new HashSet<PhoneFieldDetails> ();
    for (int i = 0; i < this.phone_nrs.size; i++) {
      if (this.phone_nrs[i] == "")
        continue;

      // XXX fix parameters here
      var phone = new PhoneFieldDetails (this.phone_nrs[i], null);
      new_details.add (phone);
    }

    return new_details;
  }
}

public class Contacts.EmailsField : PropertyField {

  protected ArrayList<string> types = new ArrayList<string> ();
  protected ArrayList<string> emails = new ArrayList<string> ();

  public EmailsField (Persona persona) {
    Object (
      property_name: "email-addresses",
      persona: persona
    );

    unowned EmailDetails? details = persona as EmailDetails;
    foreach (var email in details.email_addresses) {
      this.types.add (TypeSet.email.format_type (email));
      this.emails.add (email.value);
    }
  }

  public static bool should_show (Persona persona) {
    unowned EmailDetails? details = persona as EmailDetails;
    return (details != null && !details.email_addresses.is_empty);
  }

  protected override void create_widgets (PropertyWidget widget) {
    for (int i = 0; i < this.emails.size; i++)
      add_field (this.types[i], this.emails[i], widget);
  }

  protected virtual void add_field (string type, string email, PropertyWidget widget) {
    var type_label = row.create_type_label (type);
    var url = "mailto:" + Uri.escape_string (email, "@", false);
    var value_label = row.create_value_link (email, url);
    widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableEmailsField : EmailsField, EditableProperty {

  public EditableEmailsField (Persona? persona) {
    base (persona);
  }

  public EditableEmailsField.empty () {
    Object (
      property_name: "email-addresses",
      persona: null
    );

    this.types.add ("");
    this.emails.add ("");
  }

  protected override void add_field (string type, string email, PropertyWidget widget) {
    var type_label = row.create_type_label (type);
    var entry = row.create_value_entry (email);
    entry.changed.connect ((editable) => {
        var row_nr = row.get_child_row ((Widget) editable);
        this.emails[row_nr] = editable.get_chars ();
      });
    var delete_button = row.create_delete_button (_("Remove email address"));

    widget.add_row (type_label, entry, delete_button);
  }

  public Value? create_value () {
    if (this.emails.is_empty)
      return null;

    var new_details = create_set ();
    // Check if we only had empty emails
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_addrs = create_set ();
    yield ((EmailDetails) this.persona).change_email_addresses (new_addrs);
  }

  private HashSet<EmailFieldDetails>? create_set () {
    var new_details = new HashSet<EmailFieldDetails> ();
    for (int i = 0; i < this.emails.size; i++) {
      if (this.emails[i] != "")
        continue;

      // XXX fix parameters here
      var email = new EmailFieldDetails (this.emails[i], null);
      new_details.add (email);
    }

    return new_details;
  }
}

public class Contacts.UrlsField : PropertyField {

  protected ArrayList<string> urls = new ArrayList<string> ();

  public UrlsField (Persona persona) {
    Object (
      property_name: "urls",
      persona: persona
    );

    unowned UrlDetails? details = persona as UrlDetails;
    foreach (var url in details.urls)
      this.urls.add (url.value);
  }

  public static bool should_show (Persona persona) {
    unowned UrlDetails? details = persona as UrlDetails;
    return (details != null && !details.urls.is_empty);
  }

  protected override void create_widgets (PropertyWidget widget) {
    for (int i = 0; i < urls.size; i++)
      add_field (this.urls.get(i), widget);
  }

  protected virtual void add_field (string url, PropertyWidget widget) {
    var type_label = row.create_type_label (_("Website"));
    var url_link = Uri.escape_string (url, "@", false);
    var value_label = row.create_value_link (url, url_link);

    widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableUrlsField : UrlsField, EditableProperty {

  public EditableUrlsField (Persona? persona) {
    base (persona);
  }

  public EditableUrlsField.empty () {
    Object (
      property_name: "urls",
      persona: null
    );

    this.urls.add ("");
  }

  protected override void add_field (string url, PropertyWidget widget) {
    var type_label = row.create_type_label (_("Website"));
    var entry = row.create_value_entry (url);
    entry.changed.connect ((editable) => {
        var row_nr = row.get_child_row ((Widget) editable);
        this.urls[row_nr] = editable.get_chars ();
      });
    var delete_button = row.create_delete_button (_("Remove website"));

    widget.add_row (type_label, entry, delete_button);
  }

  public Value? create_value () {
    if (this.urls.is_empty)
      return null;

    var new_details = create_set ();
    // Check if we only had empty urls
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_urls = create_set ();
    yield ((UrlDetails) this.persona).change_urls (new_urls);
  }

  private HashSet<UrlFieldDetails>? create_set () {
    var new_details = new HashSet<UrlFieldDetails> ();
    for (int i = 0; i < this.urls.size; i++) {
      if (this.urls[i] == "")
        continue;

      // XXX fix parameters here
      var url = new UrlFieldDetails (this.urls[i], null);
      new_details.add (url);
    }

    return new_details;
  }
}

public class Contacts.NotesField : PropertyField {

  protected ArrayList<string> notes = new ArrayList<string> ();

  public NotesField (Persona persona) {
    Object (
      property_name: "notes",
      persona: persona
    );

    unowned NoteDetails? details = persona as NoteDetails;
    foreach (var note in details.notes)
      this.notes.add (note.value);
  }

  public static bool should_show (Persona persona) {
    unowned NoteDetails? details = persona as NoteDetails;
    return (details != null && !details.notes.is_empty);
  }

  protected override void create_widgets (PropertyWidget widget) {
    for (int i = 0; i < notes.size; i++)
      add_field (this.notes.get(i), widget);
  }

  protected virtual void add_field (string note, PropertyWidget widget) {
    var type_label = row.create_type_label (_("Note"));
    var value_label = row.create_value_label (note);
    widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableNotesField : NotesField, EditableProperty {

  public EditableNotesField (Persona? persona) {
    base (persona);
  }

  public EditableNotesField.empty () {
    Object (
      property_name: "note-addresses",
      persona: null
    );

    this.notes.add ("");
  }

  protected override void add_field (string note, PropertyWidget widget) {
    var type_label = row.create_type_label (_("Note"));
    var textview_container = row.create_value_textview (note);
    /* XXX entry.changed.connect ((editable) => { */
    /*     var row_nr = row.get_child_row ((Widget) editable); */
    /*     this.urls[row_nr] = editable.get_chars (); */
    /*   }); */
    var delete_button = row.create_delete_button (_("Remove note"));

    widget.add_row (type_label, textview_container, delete_button);
  }

  public Value? create_value () {
    if (this.notes.is_empty)
      return null;

    var new_details = create_set ();
    // Check if we only had empty addresses
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_addrs = create_set ();
    yield ((NoteDetails) this.persona).change_notes (new_addrs);
  }

  private HashSet<NoteFieldDetails>? create_set () {
    var new_details = new HashSet<NoteFieldDetails> ();
    for (int i = 0; i < this.notes.size; i++) {
      if (this.notes[i] == "")
        continue;

      // XXX fix parameters here
      var note = new NoteFieldDetails (this.notes[i], null);
      new_details.add (note);
    }

    return new_details;
  }
}

public class Contacts.PostalAddressesField : PropertyField {

  protected ArrayList<string> types = new ArrayList<string> ();
  protected ArrayList<PostalAddress> addresses = new ArrayList<PostalAddress> ();

  public PostalAddressesField (Persona persona) {
    Object (
      property_name: "postal-addresses",
      persona: persona
    );

    unowned PostalAddressDetails? details = persona as PostalAddressDetails;
    foreach (var address in details.postal_addresses) {
      this.types.add (TypeSet.general.format_type (address));
      this.addresses.add (address.value);
    }
  }

  public static bool should_show (Persona persona) {
    unowned PostalAddressDetails? details = persona as PostalAddressDetails;
    return (details != null && !details.postal_addresses.is_empty);
  }

  protected override void create_widgets (PropertyWidget widget) {
    for (int i = 0; i < addresses.size; i++)
      add_field (this.types.get(i), this.addresses.get(i), widget);
  }

  protected virtual void add_field (string type, PostalAddress address, PropertyWidget widget) {
    var type_label = row.create_type_label (type);
    var all_strs = string.joinv ("\n", Contact.format_address (address));
    var value_label = row.create_value_label (all_strs);
    widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditablePostalAddressesField : PostalAddressesField, EditableProperty {

  public const string[] POSTAL_ELEMENT_PROPS = { "street", "extension", "locality", "region", "postal_code", "po_box", "country"};
  public static string[] POSTAL_ELEMENT_NAMES = { _("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

  public EditablePostalAddressesField (Persona? persona) {
    base (persona);
  }

  public EditablePostalAddressesField.empty () {
    Object (
      property_name: "postal-addresses",
      persona: null
    );

    this.types.add ("");
    this.addresses.add (new PostalAddress (null, null, null, null, null, null, null, null, null));
  }

  protected override void add_field (string type, PostalAddress address, PropertyWidget widget) {
    var type_label = row.create_type_label (type);
    var grid = new Grid ();
    grid.orientation = Orientation.VERTICAL;
    for (int i = 0; i < POSTAL_ELEMENT_PROPS.length; i++) {
      unowned string address_part = POSTAL_ELEMENT_PROPS[i];
      string part;
      address.get (address_part, out part);

      var part_entry = widget.create_value_entry (part);
      part_entry.get_style_context ().add_class ("contacts-postal-entry");
      part_entry.placeholder_text = POSTAL_ELEMENT_NAMES[i];
      grid.add (part_entry);
    }
    grid.show_all ();
    var delete_button = row.create_delete_button (_("Remove postal address"));

    widget.add_row (type_label, grid, delete_button);
  }

  public Value? create_value () {
    if (this.addresses.is_empty)
      return null;

    var new_details = create_set ();
    // Check if we only had empty addresses
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_addrs = create_set ();
    yield ((PostalAddressDetails) this.persona).change_postal_addresses (new_addrs);
  }

  private HashSet<PostalAddressFieldDetails>? create_set () {
    var new_details = new HashSet<PostalAddressFieldDetails> ();
    for (int i = 0; i < this.addresses.size; i++) {
      if (is_empty_postal_address (this.addresses[i]))
        continue;

      // XXX fix parameters here
      var address = new PostalAddressFieldDetails (this.addresses[i], null);
      new_details.add (address);
    }

    return new_details;
  }

  private bool is_empty_postal_address (PostalAddress addr) {
    return addr.po_box == "" &&
           addr.extension == "" &&
           addr.street == "" &&
           addr.locality == "" &&
           addr.region == "" &&
           addr.postal_code == "" &&
           addr.country == "" &&
           addr.address_format == "";
  }
}
