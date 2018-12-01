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
 * A PersonaProperty is an abstraction of the property of a {@link Folks.Persona}.
 *
 * Since the contents of a property often isn't allowed to contain invalid
 * information -such as an empty value-, a PersonaProperty allows us to deal
 * with missing or invalid data as the user is inputting it to the UI.
 *
 * It also gives you a convenient APIT to show the property in the UI, using
 * the create_row() method, which works well with a ListBox and an underlying
 * GListModel (for example in a {@link Contacts.ContactForm}).
 */
public abstract class Contacts.PersonaProperty : Object {

  /**
   * The {@link Folks.Persona} this property belongs to.
   */
  public Persona? persona { get; construct set; default = null; }

  /**
   * The canonical name of this property, as used by libfolks.
   * Note that this often maps to a lower-case version of the VCard property.
   */
  public string property_name { get; construct set; }

  /**
   * Specifies that the property is filled, i.e. that no extra information can be added anymore.
   * For example, a Persona can only have a single birthday.
   */
  public abstract bool filled { get; }

  /**
   * Creates a widget that can show the property inside a {@link Gtk.ListBox}.
   */
  public ListBoxRow create_row (SizeGroup label_group,
                                SizeGroup value_group,
                                SizeGroup actions_group) {
    var row = new PropertyWidget (this, label_group, value_group, actions_group);
    row.margin_top = 18;
    row.hexpand = true;

    // The subclass is responsible for making the appropriate widgets
    create_widgets (row);

    row.show_all ();

    return row;
  }

  /**
   * Each subclass is responsible for creating the necessary UI and
   * incorporating it into the given {@link PropertyWidget}.
   */
  protected abstract void create_widgets (PropertyWidget prop_widget);
}

public abstract class Contacts.AggregatedPersonaProperty : PersonaProperty {

    //XXX
  /* protected ListModel elements; */

  // By default, one can always add as many elements to this property as possible
  public override bool filled { get { return false; } }

  /**
   * The number of elements in this property. For example, this will be 2 for 2 email addresses.
   */
  public abstract int n_elements { get; }
}

public interface Contacts.EditableProperty : PersonaProperty {

  /* public abstract void add_empty (string? hint); */

  /**
   * Creates a new {@link GLib.Value} from the content of this property.
   * This method is used when a new contact is created.
   */
  public abstract Value? create_value ();

  /**
   * Saves the content of this property to the {@link Folks.Persona}. Note that
   * it is a programmer error to call this when `this.persona == null`.
   *
   * XXX TODO FIXME: this will time out and fail in Edsf personas if the property didn't change.
   * Either we need to fix this in folks or make *absolutely* sure the values changed
   */
  public abstract async void save_changes () throws PropertyError;

  protected bool check_if_equal (Collection<AbstractFieldDetails> old_field_details,
                                 Collection<AbstractFieldDetails> new_field_details) {
    // Compare FieldDetails (maybe use equal_static? using a Set)
    foreach (var old_field_detail in old_field_details) {
      bool got_match = false;
      foreach (var new_field_detail in new_field_details) {
        // Check if the values are equal
        if (!old_field_detail.values_equal (new_field_detail))
          continue;

        // We can't use AbstractFieldDetails.parameters_equal here,
        // since custom labels should be compared case-sensitive, while standard
        // ones shouldn't really.

        // Only compare the fields we know about => at this point only the
        // type-related ones
        if (!TypeDescriptor.check_type_parameters_equal (old_field_detail.parameters,
                                                         new_field_detail.parameters))
          continue;

        got_match = true;
      }

      if (!got_match)
        return false;
    }

    return true;
  }
}

/**
 * Represents a way of showing a given {@link Contacts.PersonaProperty} in a
 * {@link Gtk.ListBox}, such as one would find in a ContactForm.
 */
public class Contacts.PropertyWidget : ListBoxRow {

  private Grid grid = new Grid ();

  private unowned SizeGroup labels_group;
  private unowned SizeGroup values_group;
  private unowned SizeGroup actions_group;

// The parent prop
/// XXX maybe only store the persona?
  public weak PersonaProperty prop { get; construct set; }

  construct {
    this.selectable = false;
    this.activatable = false;

    this.grid.column_spacing = 12;
    this.grid.row_spacing = 18;
    this.grid.hexpand = true;
    add (this.grid);
  }

  public PropertyWidget (PersonaProperty parent, SizeGroup labels, SizeGroup values, SizeGroup actions) {
    Object (prop: parent);

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

  public TypeCombo create_type_combo (TypeSet typeset, TypeDescriptor initial_type) {
    var combo = new TypeCombo (typeset);
    combo.active_descriptor = initial_type;
    combo.valign = Align.START;
    return combo;
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

public class Contacts.NicknameProperty : PersonaProperty {

  protected string nickname = "";

  public override bool filled { get { return this.nickname != ""; } }

  public NicknameProperty (Persona? persona) {
    Object (
      property_name: "nickname",
      persona: persona
    );

    if (persona != null)
      this.nickname = ((NameDetails) persona).nickname;
  }

  public static bool should_show (Persona persona) {
    unowned NameDetails? details = persona as NameDetails;
    return (details != null && details.nickname != "");
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    var type_label = prop_widget.create_type_label (_("Nickname"));
    var value_label = prop_widget.create_value_label (this.nickname);
    prop_widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableNicknameProperty : NicknameProperty, EditableProperty {

  private bool deleted { get; set; default = false; }

  public override bool filled { get { return base.filled && !this.deleted; } }

  public EditableNicknameProperty (Persona? persona) {
    base (persona);
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    var type_label = prop_widget.create_type_label (_("Nickname"));
    var nickname_entry = prop_widget.create_value_entry (this.nickname);
    nickname_entry.changed.connect ((editable) => {
        this.nickname = editable.get_chars ();
      });

    var delete_button = prop_widget.create_delete_button (_("Remove nickname"));
    delete_button.clicked.connect ((b) => { this.deleted = true; });
    prop_widget.add_row (type_label, nickname_entry, delete_button);
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

    if (this.deleted) {
      yield ((NameDetails) this.persona).change_nickname ("");
      return;
    }

    if (this.nickname == ((NameDetails) this.persona).nickname)
      return;

    yield ((NameDetails) this.persona).change_nickname (this.nickname);
  }
}

public class Contacts.BirthdayProperty : PersonaProperty {

  // In local timezone
  protected DateTime birthday = new DateTime.now_local ();

  // this.birthday is never null, so it is always filled
  public override bool filled { get { return true; } }

  public BirthdayProperty (Persona? persona) {
    Object (
      property_name: "birthday",
      persona: persona
    );

    if (persona != null) {
      unowned BirthdayDetails details = (BirthdayDetails) persona;
      this.birthday = details.birthday.to_local ();
    }
  }

  public static bool should_show (Persona persona) {
    unowned BirthdayDetails? details = persona as BirthdayDetails;
    return (details != null && details.birthday != null);
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    var type_label = prop_widget.create_type_label (_("Birthday"));
    var value_label = prop_widget.create_value_label (this.birthday.format ("%x"));
    prop_widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableBirthdayProperty : BirthdayProperty, EditableProperty {

  private bool deleted { get; set; default = false; }

  public override bool filled { get { return !this.deleted; } }

  public EditableBirthdayProperty (Persona? persona) {
    base (persona);
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    var type_label = prop_widget.create_type_label (_("Birthday"));
    var birthday_entry = create_date_widget ();
    var delete_button = prop_widget.create_delete_button (_("Remove birthday"));
    delete_button.clicked.connect ((b) => { this.deleted = true; });
    prop_widget.add_row (type_label, birthday_entry, delete_button);
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
    // Check if it got deleted
    if (this.birthday == null)
      return null;

    var new_value = Value (typeof (DateTime));
    new_value.set_boxed (this.birthday.to_utc ());
    return new_value;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    // The birthday property got deleted
    if (this.birthday == null) {
      yield ((BirthdayDetails) this.persona).change_birthday (null);
      return;
    }

    var new_birthday = this.birthday.to_utc ();
    if (new_birthday == ((BirthdayDetails) this.persona).birthday)
      return;

    yield ((BirthdayDetails) this.persona).change_birthday (new_birthday);
  }
}

public class Contacts.PhoneNrsProperty : AggregatedPersonaProperty {

  protected class PhoneNr : Object {
    public TypeDescriptor type_descr { get; set; }
    public string number { get; set; default = ""; }
    public MultiMap<string, string>? parameters { get; set; default = null; }
    public bool deleted { get; set; default = false; }

    public PhoneNr.dummy (string type_str) {
      Object (type_descr: TypeSet.phone.lookup_descriptor_in_store (type_str));
    }

    public PhoneNr (PhoneFieldDetails details) {
      Object (type_descr: TypeSet.phone.lookup_descriptor_for_field_details (details),
              number: details.value,
              parameters: details.parameters);
    }
  }

  protected Gee.List<PhoneNr?> phone_nrs = new ArrayList<PhoneNr?> ();

  public override int n_elements { get { return this.phone_nrs.size; } }

  public PhoneNrsProperty (Persona persona) {
    Object (
      property_name: "phone-numbers",
      persona: persona
    );

    if (this.persona != null) {
      foreach (var phone in ((PhoneDetails?) persona).phone_numbers) {
        this.phone_nrs.add (new PhoneNr (phone));
      }
    }
  }

  public static bool should_show (Persona persona) {
    unowned PhoneDetails? details = persona as PhoneDetails;
    return (details != null && !details.phone_numbers.is_empty);
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    foreach (PhoneNr phone_nr in this.phone_nrs)
      add_field (prop_widget, phone_nr);
  }

  protected virtual void add_field (PropertyWidget prop_widget, PhoneNr phone_nr) {
    var type_label = prop_widget.create_type_label (phone_nr.type_descr.display_name);
    var value_label = prop_widget.create_value_label (phone_nr.number);
    prop_widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditablePhoneNrsProperty : PhoneNrsProperty, EditableProperty {

  public EditablePhoneNrsProperty (Persona? persona) {
    base (persona);

    if (persona == null) {
      // Fill in a dummy value
      this.phone_nrs.add (new PhoneNrsProperty.PhoneNr.dummy ("Mobile"));
    }
  }

  protected override void add_field (PropertyWidget prop_widget, PhoneNrsProperty.PhoneNr phone_nr) {
    var type_combo = prop_widget.create_type_combo (TypeSet.phone, phone_nr.type_descr);
    type_combo.changed.connect ((combo) => {
        phone_nr.type_descr = type_combo.active_descriptor;
      });

    var entry = prop_widget.create_value_entry (phone_nr.number);
    entry.changed.connect ((editable) => {
        phone_nr.number = editable.get_chars ();
      });

    var delete_button = prop_widget.create_delete_button (_("Remove phone number"));
    delete_button.clicked.connect ((b) => {
        phone_nr.deleted = true;
      });

    prop_widget.add_row (type_combo, entry, delete_button);
  }

  public Value? create_value () {
    if (this.phone_nrs.is_empty)
      return null;

    var new_details = create_new_field_details ();

    // Check if we only had empty phone_nrs
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_phone_nrs = create_new_field_details ();

    // Check if we didn't have any changes. This is a necessary step
    // XXX explain why (timeout)
    var old_phone_nrs = ((PhoneDetails) this.persona).phone_numbers;
    if (!check_if_equal (old_phone_nrs, new_phone_nrs))
      yield ((PhoneDetails) this.persona).change_phone_numbers (new_phone_nrs);
  }

  private HashSet<PhoneFieldDetails>? create_new_field_details () {
    var new_details = new HashSet<PhoneFieldDetails> ();
    foreach (PhoneNrsProperty.PhoneNr phone_nr in this.phone_nrs) {
      if (phone_nr.number == "" || phone_nr.deleted)
        continue;

      var parameters = phone_nr.type_descr.add_type_to_parameters (phone_nr.parameters);
      var phone = new PhoneFieldDetails (phone_nr.number, parameters);
      new_details.add (phone);
    }

    return new_details;
  }
}

public class Contacts.EmailsProperty : AggregatedPersonaProperty {

  protected class Email : Object {
    public TypeDescriptor type_descr { get; set; }
    public string address { get; set; default = ""; }
    public MultiMap<string, string>? parameters { get; set; default = null; }
    public bool deleted { get; set; default = false; }

    public Email.dummy (string type_str) {
      Object (type_descr: TypeSet.email.lookup_descriptor_in_store (type_str));
    }

    public Email (EmailFieldDetails details) {
      Object (type_descr: TypeSet.email.lookup_descriptor_for_field_details (details),
              address: details.value,
              parameters: details.parameters);
    }
  }

  protected Gee.List<Email> emails = new ArrayList<Email> ();

  public override int n_elements { get { return this.emails.size; } }

  public EmailsProperty (Persona? persona) {
    Object (
      property_name: "email-addresses",
      persona: persona
    );

    if (persona != null) {
      unowned EmailDetails? details = persona as EmailDetails;
      foreach (var email in details.email_addresses)
        this.emails.add (new Email (email));
    }
  }

  public static bool should_show (Persona persona) {
    unowned EmailDetails? details = persona as EmailDetails;
    return (details != null && !details.email_addresses.is_empty);
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    foreach (var email in this.emails)
      add_field (prop_widget, email);
  }

  protected virtual void add_field (PropertyWidget prop_widget, Email email) {
    var type_label = prop_widget.create_type_label (email.type_descr.display_name);
    var url = "mailto:" + Uri.escape_string (email.address, "@", false);
    var value_label = prop_widget.create_value_link (email.address, url);
    prop_widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableEmailsProperty : EmailsProperty, EditableProperty {

  public EditableEmailsProperty (Persona? persona) {
    base (persona);

    if (persona == null)
      this.emails.add (new Email.dummy ("Personal"));
  }

  protected override void add_field (PropertyWidget prop_widget, EmailsProperty.Email email) {
    var type_combo = prop_widget.create_type_combo (TypeSet.email, email.type_descr);
    type_combo.changed.connect ((combo) => {
        email.type_descr = type_combo.active_descriptor;
      });

    var entry = prop_widget.create_value_entry (email.address);
    entry.changed.connect ((editable) => {
        email.address = editable.get_chars ();
      });
    var delete_button = prop_widget.create_delete_button (_("Remove email address"));

    prop_widget.add_row (type_combo, entry, delete_button);
  }

  public Value? create_value () {
    if (this.emails.is_empty)
      return null;

    var new_details = create_new_field_details ();
    // Check if we only had empty emails
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_emails = create_new_field_details ();
    var old_emails = ((EmailDetails) this.persona).email_addresses;

    if (!check_if_equal (old_emails, new_emails))
      yield ((EmailDetails) this.persona).change_email_addresses (new_emails);
  }

  private HashSet<EmailFieldDetails>? create_new_field_details () {
    var new_details = new HashSet<EmailFieldDetails> ();
    foreach (var email in this.emails) {
      if (email.address != "" || email.deleted)
        continue;

      var parameters = email.type_descr.add_type_to_parameters (email.parameters);
      var details = new EmailFieldDetails (email.address, parameters);
      new_details.add (details);
    }

    return new_details;
  }
}

public class Contacts.UrlsProperty : AggregatedPersonaProperty {

  protected class Url : Object {
    public string url { get; set; default = ""; }
    public MultiMap<string, string>? parameters { get; set; default = null; }
    public bool deleted { get; set; default = false; }

    public Url.dummy () {
    }

    public Url (UrlFieldDetails details) {
      Object (url: details.value, parameters: details.parameters);
    }
  }

  protected Gee.List<Url> urls = new ArrayList<Url> ();

  public override int n_elements { get { return this.urls.size; } }

  public UrlsProperty (Persona? persona) {
    Object (
      property_name: "urls",
      persona: persona
    );

    if (persona != null) {
      unowned UrlDetails? details = persona as UrlDetails;
      foreach (var detail in details.urls)
        this.urls.add (new Url (detail));
    }
  }

  public static bool should_show (Persona persona) {
    unowned UrlDetails? details = persona as UrlDetails;
    return (details != null && !details.urls.is_empty);
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    foreach (var url in this.urls)
      add_field (prop_widget, url);
  }

  protected virtual void add_field (PropertyWidget prop_widget, Url url) {
    var type_label = prop_widget.create_type_label (_("Website"));
    var url_link = Uri.escape_string (url.url, "@", false);
    var value_label = prop_widget.create_value_link (url.url, url_link);

    prop_widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableUrlsProperty : UrlsProperty, EditableProperty {

  public EditableUrlsProperty (Persona? persona) {
    base (persona);

    if (persona == null)
      this.urls.add (new Url.dummy());
  }

  protected override void add_field (PropertyWidget prop_widget, UrlsProperty.Url url) {
    var type_label = prop_widget.create_type_label (_("Website"));
    var entry = prop_widget.create_value_entry (url.url);
    entry.changed.connect ((editable) => {
        url.url = editable.get_chars ();
      });
    var delete_button = prop_widget.create_delete_button (_("Remove website"));

    prop_widget.add_row (type_label, entry, delete_button);
  }

  public Value? create_value () {
    if (this.urls.is_empty)
      return null;

    var new_details = create_new_field_details ();
    // Check if we only had empty urls
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_urls = create_new_field_details ();
    yield ((UrlDetails) this.persona).change_urls (new_urls);
  }

  private HashSet<UrlFieldDetails>? create_new_field_details () {
    var new_details = new HashSet<UrlFieldDetails> ();
    foreach (var url in this.urls) {
      if (url.url == "" || url.deleted)
        continue;

      var url_details = new UrlFieldDetails (url.url, url.parameters);
      new_details.add (url_details);
    }

    return new_details;
  }
}

public class Contacts.NotesProperty : AggregatedPersonaProperty {

  protected class Note : Object {
    public string text { get; set; default = ""; }
    public MultiMap<string, string>? parameters { get; set; default = null; }
    public bool deleted { get; set; default = false; }

    public Note.dummy () {
    }

    public Note (NoteFieldDetails details) {
      Object (text: details.value, parameters: details.parameters);
    }
  }

  protected Gee.List<Note> notes = new ArrayList<Note> ();

  public override int n_elements { get { return this.notes.size; } }

  public NotesProperty (Persona? persona) {
    Object (
      property_name: "notes",
      persona: persona
    );

    if (persona != null) {
      unowned NoteDetails? details = persona as NoteDetails;
      foreach (var note_detail in details.notes)
        this.notes.add (new Note (note_detail));
    }
  }

  public static bool should_show (Persona persona) {
    unowned NoteDetails? details = persona as NoteDetails;
    return (details != null && !details.notes.is_empty);
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    foreach (var note in this.notes)
      add_field (prop_widget, note);
  }

  protected virtual void add_field (PropertyWidget prop_widget, Note note) {
    var type_label = prop_widget.create_type_label (_("Note"));
    var value_label = prop_widget.create_value_label (note.text);
    prop_widget.add_row (type_label, value_label);
  }
}

public class Contacts.EditableNotesProperty : NotesProperty, EditableProperty {

  public EditableNotesProperty (Persona persona) {
    base (persona);

    if (persona == null)
      this.notes.add (new Note.dummy ());
  }

  protected override void add_field (PropertyWidget prop_widget, NotesProperty.Note note) {
    var type_label = prop_widget.create_type_label (_("Note"));
    var textview_container = prop_widget.create_value_textview (note.text);
    /* XXX entry.changed.connect ((editable) => { */
    /*     this.urls[row_nr] = editable.get_chars (); */
    /*   }); */
    var delete_button = prop_widget.create_delete_button (_("Remove note"));

    prop_widget.add_row (type_label, textview_container, delete_button);
  }

  public Value? create_value () {
    if (this.notes.is_empty)
      return null;

    var new_details = create_new_field_details ();
    // Check if we only had empty addresses
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_addrs = create_new_field_details ();
    yield ((NoteDetails) this.persona).change_notes (new_addrs);
  }

  private HashSet<NoteFieldDetails>? create_new_field_details () {
    var new_details = new HashSet<NoteFieldDetails> ();
    foreach (var note in this.notes) {
      if (note.text == "" || note.deleted)
        continue;

      var note_detail = new NoteFieldDetails (note.text, note.parameters);
      new_details.add (note_detail);
    }

    return new_details;
  }
}

public class Contacts.PostalAddressesProperty : AggregatedPersonaProperty {

  // Note that this is a wrapper around Folkd.PostalAddress
  protected class PostalAddr : Object {
    public TypeDescriptor type_descr { get; set; }
    public PostalAddress address { get; set;  }
    public MultiMap<string, string>? parameters { get; set; default = null; }
    public bool deleted { get; set; default = false; }

    public PostalAddr.dummy (string type_str) {
      Object (
        type_descr: TypeSet.general.lookup_descriptor_in_store (type_str),
        address: new PostalAddress("", "", "", "", "", "", "", "", "")
      );
    }

    public PostalAddr (PostalAddressFieldDetails details) {
      Object (type_descr: TypeSet.general.lookup_descriptor_for_field_details (details),
              address: details.value,
              parameters: details.parameters);
    }

    public bool is_empty () {
      return this.address.po_box == "" &&
             this.address.extension == "" &&
             this.address.street == "" &&
             this.address.locality == "" &&
             this.address.region == "" &&
             this.address.postal_code == "" &&
             this.address.country == "" &&
             this.address.address_format == "";
    }
  }

  protected Gee.List<PostalAddr> addresses = new ArrayList<PostalAddr> ();

  public override int n_elements { get { return this.addresses.size; } }

  public PostalAddressesProperty (Persona? persona) {
    Object (
      property_name: "postal-addresses",
      persona: persona
    );

    if (persona != null) {
      unowned PostalAddressDetails? details = persona as PostalAddressDetails;
      foreach (var address_details in details.postal_addresses) {
        this.addresses.add (new PostalAddr (address_details));
      }
    }
  }

  public static bool should_show (Persona persona) {
    unowned PostalAddressDetails? details = persona as PostalAddressDetails;
    return (details != null && !details.postal_addresses.is_empty);
  }

  protected override void create_widgets (PropertyWidget prop_widget) {
    foreach (var addr in this.addresses)
      add_field (prop_widget, addr);
  }

  protected virtual void add_field (PropertyWidget prop_widget, PostalAddr addr) {
    var type_label = prop_widget.create_type_label (addr.type_descr.display_name);
    var value_label = prop_widget.create_value_label (format_address (addr.address));
    prop_widget.add_row (type_label, value_label);
  }

  private static string format_address (PostalAddress addr) {
    string[] lines = {};

    if (addr.street != "")
      lines += addr.street;
    if (addr.extension != "")
      lines += addr.extension;
    if (addr.locality != "")
      lines += addr.locality;
    if (addr.region != "")
      lines += addr.region;
    if (addr.postal_code != "")
      lines += addr.postal_code;
    if (addr.po_box != "")
      lines += addr.po_box;
    if (addr.country != "")
      lines += addr.country;
    if (addr.address_format != "")
      lines += addr.address_format;

    return string.joinv ("\n", lines);
  }
}

public class Contacts.EditablePostalAddressesProperty : PostalAddressesProperty, EditableProperty {

  public const string[] POSTAL_ELEMENT_PROPS = { "street", "extension", "locality", "region", "postal_code", "po_box", "country"};
  public static string[] POSTAL_ELEMENT_NAMES = { _("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")};

  public EditablePostalAddressesProperty (Persona? persona) {
    base (persona);

    if (persona == null)
      this.addresses.add (new PostalAddr.dummy ("Home"));
  }

  protected override void add_field (PropertyWidget prop_widget, PostalAddressesProperty.PostalAddr addr) {
    var type_combo = prop_widget.create_type_combo (TypeSet.general, addr.type_descr);
    type_combo.changed.connect ((combo) => {
        addr.type_descr = type_combo.active_descriptor;
      });

    var grid = new Grid ();
    grid.orientation = Orientation.VERTICAL;
    for (int i = 0; i < POSTAL_ELEMENT_PROPS.length; i++) {
      unowned string address_part = POSTAL_ELEMENT_PROPS[i];
      string part;
      addr.address.get (address_part, out part);

      var part_entry = prop_widget.create_value_entry (part);
      part_entry.get_style_context ().add_class ("contacts-postal-entry");
      part_entry.placeholder_text = POSTAL_ELEMENT_NAMES[i];
      grid.add (part_entry);
    }
    grid.show_all ();
    var delete_button = prop_widget.create_delete_button (_("Remove postal address"));

    prop_widget.add_row (type_combo, grid, delete_button);
  }

  public Value? create_value () {
    if (this.addresses.is_empty)
      return null;

    var new_details = create_new_field_details ();
    // Check if we only had empty addresses
    if (new_details.is_empty)
      return null;

    var result = Value (new_details.get_type ());
    result.set_object (new_details);
    return result;
  }

  public async void save_changes () throws PropertyError {
    assert (this.persona != null);

    var new_addrs = create_new_field_details ();

    var old_addrs = ((PostalAddressDetails) this.persona).postal_addresses;
    if (!check_if_equal (old_addrs, new_addrs))
      yield ((PostalAddressDetails) this.persona).change_postal_addresses (new_addrs);
  }

  private HashSet<PostalAddressFieldDetails>? create_new_field_details () {
    var new_details = new HashSet<PostalAddressFieldDetails> ();
    foreach (var addr in this.addresses) {
      if (addr.is_empty() || addr.deleted)
        continue;

      var parameters = addr.type_descr.add_type_to_parameters (addr.parameters);
      var address = new PostalAddressFieldDetails (addr.address, parameters);
      new_details.add (address);
    }

    return new_details;
  }
}
