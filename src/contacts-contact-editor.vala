/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 * Copyright (C) 2019 Purism SPC
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * A widget that allows the user to edit a given {@link Contact}.
 */
public class Contacts.ContactEditor : Gtk.Widget {

  /** The contact we're editing */
  public unowned Contact contact { get; construct set; }

  /** The set of distinct personas (or null) that are part of the contact */
  private GenericArray<Persona?> personas = new GenericArray<Persona?> ();

  construct {
    var box_layout = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
    box_layout.spacing = 12;
    set_layout_manager (box_layout);

    add_css_class ("contacts-contact-editor");

    contact.items_changed.connect (on_contact_items_changed);
    on_contact_items_changed (contact, 0, 0, contact.get_n_items ());
  }

  public ContactEditor (Contact contact) {
    Object (contact: contact);
  }

  public override void dispose () {
    unowned Gtk.Widget? child = null;
    while ((child = get_first_child ()) != null)
      child.unparent ();
    base.dispose ();
  }

  private void on_contact_items_changed (GLib.ListModel model,
                                         uint position,
                                         uint removed,
                                         uint added) {
    for (uint i = position; i < position + added; i++) {
      var chunk = (Chunk) model.get_item (i);

      // Only add the persona if we can't find it
      if (this.personas.find (chunk.persona))
        continue;

      this.personas.add (chunk.persona);

      // Add a header, except for the first persona
      if (chunk.persona != null && this.personas.length > 1) {
        var persona_store_header = create_persona_store_label (chunk.persona);
        persona_store_header.set_parent (this);
      }

      var persona_editor = new PersonaEditor ((Contact) model, chunk.persona);
      persona_editor.set_parent (this);
    }

    // NOTE: we don't support removing personas here but that should be okay,
    // since people shouldn't be deleting personas in the first place while
    // they're still editing
  }

  private Gtk.Label create_persona_store_label (Persona p) {
    var store_name = new Gtk.Label (Utils.format_persona_store_name_for_contact (p));
    var attrList = new Pango.AttrList ();
    attrList.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
    store_name.set_attributes (attrList);
    store_name.halign = Gtk.Align.START;
    store_name.ellipsize = Pango.EllipsizeMode.MIDDLE;
    return store_name;
  }
}

public class Contacts.PersonaEditor : Gtk.Widget {

  /** The contact we're editing a (possibly non-existent) persona of */
  public unowned Contact contact { get; construct set; }

  /** The specific persona of the contact we're editing */
  public unowned Persona? persona { get; construct set; }

  // We need to keep a reference to the sorted and filtered list model
  private ListModel model;

  public const string[] IMPORTANT_PROPERTIES = {
    "avatar",
    "full-name",
    "email-addresses",
    "phone-numbers",
    null
  };

  public const string[] SUPPORTED_PROPERTIES = {
    "avatar",
    "full-name",
    "birthday",
    "email-addresses",
    "nickname",
    "notes",
    "phone-numbers",
    "postal-addresses",
    "roles",
    "urls",
    null
  };

  construct {
    var box_layout = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
    box_layout.spacing = 6;
    set_layout_manager (box_layout);

    add_css_class ("contacts-persona-editor");

    ensure_chunks (this.contact);

    var persona_filter = new Gtk.CustomFilter ((item) => {
      return ((Chunk) item).persona == this.persona;
    });
    var persona_model = new Gtk.FilterListModel (this.contact, (owned) persona_filter);
    warn_if_fail (persona_model.get_n_items () > 0);

    // Show all properties that we either ...
    var filter = new Gtk.AnyFilter ();

    // 1. always want to show
    var prop_filter = new ChunkPropertyFilter (IMPORTANT_PROPERTIES);
    filter.append (prop_filter);

    // 2. want to show if they are filled in _and_ supported
    var non_empty_filter = new Gtk.EveryFilter ();
    non_empty_filter.append (new ChunkEmptyFilter ());
    non_empty_filter.append (new ChunkPropertyFilter (SUPPORTED_PROPERTIES));
    filter.append (non_empty_filter);

    var filtered = new Gtk.FilterListModel (persona_model, filter);
    this.model = new Gtk.SortListModel (filtered, new ChunkSorter ());
    model.items_changed.connect (on_model_items_changed);
    on_model_items_changed (model, 0, 0, model.get_n_items ());

    // Create the "show more" button
    add_show_more_button (prop_filter);
  }

  public PersonaEditor (Contact contact, Persona? persona) {
    Object (contact: contact, persona: persona);
  }

  public override void dispose () {
    unowned Gtk.Widget? child = null;
    while ((child = get_first_child ()) != null)
      child.unparent ();

    base.dispose ();
  }

  private void ensure_chunks (Contact contact) {
    // We can't check what properties will be writable by a persona store
    // beforehand, so just create an empty chunk for each property we support
    unowned var writeable_props = SUPPORTED_PROPERTIES;
    if (persona != null)
      writeable_props = persona.writeable_properties;

    foreach (unowned var prop in writeable_props) {
      if (prop == null) // Oh Vala
          continue;

      if (contact.get_most_relevant_chunk (prop, true) == null) {
        contact.create_chunk (prop, persona);
      }
    }
  }

  // private void add_show_more_button (Gtk.AnyFilter filter) {
  private void add_show_more_button (ChunkPropertyFilter filter) {
    var show_more_row = new Adw.ButtonRow ();
    var listbox = new Adw.PreferencesGroup ();

    listbox.add (show_more_row);
    listbox.set_parent (this);

    show_more_row.start_icon_name = "view-more-symbolic";
    show_more_row.use_underline = true;
    show_more_row.title = _("_Show More");
    show_more_row.activated.connect (() => {
      listbox.unparent ();
      filter.allowed_properties.splice (0,
                                        filter.allowed_properties.get_n_items (),
                                        SUPPORTED_PROPERTIES);
    });
  }

  private void on_model_items_changed (GLib.ListModel model,
                                       uint position,
                                       uint removed,
                                       uint added) {
    // Get the widget where we'll have to insert/remove the item at "position"
    unowned var child = get_first_child ();

    uint current_position = 0;
    while (current_position < position) {
      child = child.get_next_sibling ();
      // If this fails, we somehow have less widgets than items in our model
      warn_if_fail (child != null);
      current_position++;
    }

    // First, remove the ones that were removed from the model too
    while (removed > 0) {
      unowned var to_remove = child;
      child = to_remove.get_next_sibling ();
      to_remove.unparent ();
      removed--;
    }

    // Now, add the new ones
    for (uint i = position; i < position + added; i++) {
      var chunk = (Chunk) model.get_item (i);
      var new_child = create_widget_for_chunk (chunk);
      if (new_child != null)
        new_child.insert_before (this, child);
    }
  }

  private Gtk.Widget? create_widget_for_chunk (Chunk chunk) {
    switch (chunk.property_name) {
      // Please keep these sorted
      case "avatar":
        return create_widget_for_avatar (chunk);
      case "birthday":
        return create_widget_for_birthday (chunk);
      case "email-addresses":
        return create_widget_for_emails (chunk);
      case "full-name":
        return create_widget_for_full_name (chunk);
      case "nickname":
        return create_widget_for_nickname (chunk);
      case "notes":
        return create_widget_for_notes (chunk);
      case "phone-numbers":
        return create_widget_for_phones (chunk);
      case "postal-addresses":
        return create_widget_for_addresses (chunk);
      case "roles":
        return create_widget_for_roles (chunk);
      case "urls":
        return create_widget_for_urls (chunk);
      default:
        debug ("Unsupported property: %s", chunk.property_name);
        return null;
    }
  }

  private Gtk.Widget create_widget_for_avatar (Chunk chunk)
      requires (chunk is AvatarChunk) {
    var avatar = new EditableAvatar (contact, PROFILE_SIZE);
    avatar.halign = Gtk.Align.CENTER;
    avatar.margin_bottom = 12;
    return avatar;
  }

  private Gtk.Widget create_widget_for_emails (Chunk chunk)
      requires (chunk is EmailAddressesChunk) {

    unowned var emails_chunk = (EmailAddressesChunk) chunk;
    var group = new ContactEditorGroup (contact, persona, emails_chunk, create_email_widget);
    return group;
  }

  private ContactEditorProperty create_email_widget (BinChunkChild chunk_child) {
    var row = new Adw.EntryRow ();

    var icon = new Gtk.Image.from_icon_name (chunk_child.icon_name);
    chunk_child.bind_property ("icon-name", icon, "icon-name", BindingFlags.SYNC_CREATE);
    row.add_prefix (icon);

    row.title = _("Add email");
    row.set_input_purpose (Gtk.InputPurpose.EMAIL);
    chunk_child.bind_property ("raw-address", row, "text",
                               BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

    var widget = new ContactEditorProperty (row);
    widget.add_type_combo (chunk_child, TypeSet.email);

    return widget;
  }

  private Gtk.Widget create_widget_for_phones (Chunk chunk)
      requires (chunk is PhonesChunk) {

    unowned var phones_chunk = (PhonesChunk) chunk;
    var group = new ContactEditorGroup (contact, persona, phones_chunk, create_phone_widget);
    return group;
  }

  private ContactEditorProperty create_phone_widget (BinChunkChild chunk_child) {
    var row = new Adw.EntryRow ();

    var icon = new Gtk.Image.from_icon_name (chunk_child.icon_name);
    chunk_child.bind_property ("icon-name", icon, "icon-name", BindingFlags.SYNC_CREATE);
    row.add_prefix (icon);

    row.title = _("Add phone number");
    row.set_input_purpose (Gtk.InputPurpose.PHONE);
    row.set_direction (Gtk.TextDirection.LTR);
    chunk_child.bind_property ("raw-number", row, "text",
                               BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

    var widget = new ContactEditorProperty (row);
    widget.add_type_combo (chunk_child, TypeSet.phone);

    return widget;
  }

  private Gtk.Widget create_widget_for_urls (Chunk chunk)
      requires (chunk is UrlsChunk) {

    unowned var urls_chunk = (UrlsChunk) chunk;
    var group = new ContactEditorGroup (contact, persona, urls_chunk, create_url_widget);
    return group;
  }

  private ContactEditorProperty create_url_widget (BinChunkChild chunk_child) {
    var row = new Adw.EntryRow ();

    var icon = new Gtk.Image.from_icon_name (chunk_child.icon_name);
    chunk_child.bind_property ("icon-name", icon, "icon-name", BindingFlags.SYNC_CREATE);
    row.add_prefix (icon);

    row.title = _("Website");
    row.set_input_purpose (Gtk.InputPurpose.URL);
    chunk_child.bind_property ("raw-url", row, "text",
                               BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

    return new ContactEditorProperty (row);
  }

  private Gtk.Widget create_widget_for_full_name (Chunk chunk)
      requires (chunk is FullNameChunk) {
    var row = new Adw.EntryRow ();
    row.title = _("Full name");
    row.set_input_purpose (Gtk.InputPurpose.NAME);
    chunk.bind_property ("full-name", row, "text", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

    return new ContactEditorProperty (row);
  }

  private Gtk.Widget create_widget_for_nickname (Chunk chunk)
      requires (chunk is NicknameChunk) {
    var row = new Adw.EntryRow ();
    row.add_prefix (new Gtk.Image.from_icon_name ("avatar-default-symbolic"));
    row.title = _("Nickname");
    row.set_input_purpose (Gtk.InputPurpose.NAME);
    chunk.bind_property ("nickname", row, "text", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

    return new ContactEditorProperty (row);
  }

  private Gtk.Widget create_widget_for_notes (Chunk chunk)
      requires (chunk is NotesChunk) {
    unowned var notes_chunk = (NotesChunk) chunk;
    var group = new ContactEditorGroup (contact, persona, notes_chunk, create_note_widget);
    return group;
  }

  private ContactEditorProperty create_note_widget (BinChunkChild chunk_child) {
    //XXX create a subclass NoteEditor instead
    var row = new Adw.PreferencesRow ();

    var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    header.add_css_class ("header");
    row.set_child (header);

    var prefixes = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    prefixes.add_css_class ("prefixes");
    var icon = new Gtk.Image.from_icon_name (chunk_child.icon_name);
    chunk_child.bind_property ("icon-name", icon, "icon-name", BindingFlags.SYNC_CREATE);
    prefixes.append (icon);
    header.append (prefixes);

    var sw = new Gtk.ScrolledWindow ();
    sw.focusable = false;
    sw.has_frame = false;
    sw.set_size_request (-1, 100);

    var textview = new Gtk.TextView ();
    chunk_child.bind_property ("text", textview.buffer, "text",
                               BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
    textview.hexpand = true;
    sw.set_child (textview);

    header.append (sw);

    return new ContactEditorProperty (row);
  }

  private Gtk.Widget create_widget_for_birthday (Chunk chunk)
      requires (chunk is BirthdayChunk) {
    var bd_chunk = (BirthdayChunk) chunk;

    var row = new Adw.ActionRow ();
    row.add_prefix (new Gtk.Image.from_icon_name ("birthday-symbolic"));
    row.title = _("Birthday");

    // Show a button to set the date (and show it if set)
    var bd_button = new Gtk.Button ();
    bd_button.valign = Gtk.Align.CENTER;
    update_birthday_button (bd_button, bd_chunk);
    bd_button.clicked.connect (() => {
      unowned var parent_window = get_root () as Gtk.Window;
      var dialog = new BirthdayEditor (bd_chunk.birthday);
      dialog.changed.connect (() => {
        if (dialog.is_set)
          bd_chunk.birthday = dialog.get_birthday ();
      });
      dialog.present (parent_window);
    });
    row.add_suffix (bd_button);
    row.set_activatable_widget (bd_button);

    // Add a remove button
    var remove_button = new Gtk.Button ();
    remove_button.icon_name = "user-trash-symbolic";
    remove_button.tooltip_text = _("Remove birthday");
    remove_button.valign = Gtk.Align.CENTER;
    remove_button.add_css_class ("flat");
    remove_button.sensitive = (bd_chunk.birthday != null);
    remove_button.clicked.connect ((b) => { bd_chunk.birthday = null; });
    row.add_suffix (remove_button);

    // Update both buttons on any changes
    bd_chunk.notify["birthday"].connect ((obj, pspec) => {
      update_birthday_button (bd_button, bd_chunk);
      remove_button.sensitive = (bd_chunk.birthday != null);
    });

    return new ContactEditorProperty (row);
  }

  private void update_birthday_button (Gtk.Button bd_button, BirthdayChunk bd_chunk) {
    if (bd_chunk.birthday == null) {
      bd_button.label = _("Set Birthday");
    } else {
      bd_button.label = bd_chunk.birthday.to_local ().format ("%x");
    }
  }

  private Gtk.Widget create_widget_for_addresses (Chunk chunk)
      requires (chunk is AddressesChunk) {
    unowned var addresses_chunk = (AddressesChunk) chunk;
    var group = new ContactEditorGroup (contact, persona, addresses_chunk, create_address_widget);
    return group;
  }

  private ContactEditorProperty create_address_widget (BinChunkChild chunk_child) {
    unowned var address_chunk = (Address) chunk_child;
    //XXX create a subclass AddressEditor instead
    var row = new Adw.PreferencesRow ();

    var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    header.add_css_class ("header");
    row.set_child (header);

    var prefixes = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    prefixes.add_css_class ("prefixes");
    var icon = new Gtk.Image.from_icon_name (chunk_child.icon_name);
    chunk_child.bind_property ("icon-name", icon, "icon-name", BindingFlags.SYNC_CREATE);
    prefixes.append (icon);
    header.append (prefixes);

    var editor = new AddressEditor (address_chunk);
    editor.hexpand = true;
    header.append (editor);

    var widget = new ContactEditorProperty (row);
    widget.add_type_combo (chunk_child, TypeSet.general);
    return widget;
  }

  private Gtk.Widget create_widget_for_roles (Chunk chunk)
      requires (chunk is RolesChunk) {

    unowned var roles_chunk = (RolesChunk) chunk;
    var group = new ContactEditorGroup (contact, persona, roles_chunk, create_role_widget);
    return group;
  }

  private ContactEditorProperty create_role_widget (BinChunkChild chunk_child) {
    unowned var role_chunk = (OrgRole) chunk_child;

    // 2 rows: one for the role, one for the org
    var org_row = new Adw.EntryRow ();
    var icon = new Gtk.Image.from_icon_name (chunk_child.icon_name);
    chunk_child.bind_property ("icon-name", icon, "icon-name", BindingFlags.SYNC_CREATE);
    org_row.add_prefix (icon);
    org_row.title = _("Organization");
    role_chunk.role.bind_property ("organisation-name", org_row, "text",
                                   BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
    var widget = new ContactEditorProperty (org_row);

    var role_row = new Adw.EntryRow ();
    role_row.title = _("Role");
    role_chunk.role.bind_property ("title", role_row, "text",
                                   BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
    widget.add (role_row);

    return widget;
  }
}

/** A widget for {@link BinChunk}s, allowing to create a widget for each */
public class Contacts.ContactEditorGroup : Gtk.Widget {

  public unowned Contact contact { get; construct set; }

  public unowned Persona? persona { get; construct set; }

  public delegate ContactEditorProperty CreateWidgetFunc (BinChunkChild chunk_child);

  private unowned CreateWidgetFunc create_widget_func;

  construct {
    var box_layout = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
    box_layout.spacing = 6;
    set_layout_manager (box_layout);

    add_css_class ("contact-editor-group");
  }

  public ContactEditorGroup (Contact contact, Persona? persona, BinChunk chunk, CreateWidgetFunc func) {
    Object (contact: contact, persona: persona);

    this.create_widget_func = func;

    chunk.items_changed.connect (on_bin_chunk_items_changed);
    on_bin_chunk_items_changed (chunk, 0, 0, chunk.get_n_items ());
  }

  public override void dispose () {
    unowned Gtk.Widget? child = null;
    while ((child = get_first_child ()) != null)
      child.unparent ();

    base.dispose ();
  }

  private void on_bin_chunk_items_changed (GLib.ListModel model,
                                           uint position,
                                           uint removed,
                                           uint added) {
    // Get the widget where we'll have to insert/remove the item at "position"
    unowned var child = get_first_child ();

    uint current_position = 0;
    while (current_position < position) {
      child = child.get_next_sibling ();
      current_position++;
    }

    // First, remove the ones that were removed from the model too
    while (removed > 0) {
      unowned var to_remove = child;
      child = to_remove.get_next_sibling ();
      to_remove.unparent ();
      removed--;
    }

    // Now, add the new ones
    for (uint i = position; i < position + added; i++) {
      var chunk_child = (BinChunkChild) model.get_item (i);
      var new_child = this.create_widget_func (chunk_child);
      if (new_child != null) {
        // Before inserting the child, make sure reveal is false
        // We turn it on _after_ adding it, so the animation is visible
        new_child.reveal = false;
        new_child.insert_before (this, child);
        new_child.reveal = true;
      }
    }
  }
}

/**
 * Widget wrapper to show a single property of a contact (for example an email
 * address, a birthday, ...). It can show itself using a GtkRevealer animation.
 */
public class Contacts.ContactEditorProperty : Gtk.Widget {

  private unowned Adw.PreferencesGroup group;

  public bool reveal { get; set; default = true; }

  static construct {
    set_layout_manager_type (typeof (Gtk.BinLayout));
  }

  public ContactEditorProperty (Gtk.Widget widget) {
    var inner_revealer = new Gtk.Revealer ();
    inner_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;

    var revealer = new Gtk.Revealer ();
    revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
    revealer.set_parent (this);

    var prefs_group = new Adw.PreferencesGroup ();
    prefs_group.add_css_class ("contacts-editor-property");
    this.group = prefs_group;
    inner_revealer.set_child (prefs_group);
    revealer.set_child (inner_revealer);
    revealer.bind_property ("child-revealed", inner_revealer, "reveal-child", BindingFlags.SYNC_CREATE);
    bind_property ("reveal", revealer, "reveal-child", BindingFlags.SYNC_CREATE);

    group.add (widget);
  }

  public override void dispose () {
    get_first_child ().unparent ();
    base.dispose ();
  }

  public void add_type_combo (BinChunkChild chunk_child,
                              TypeSet combo_type) {
    var row = new TypeComboRow (combo_type);
    row.title = _("Label");
    row.set_selected_from_parameters (chunk_child.parameters);
    add (row);

    row.notify["selected-item"].connect ((obj, pspec) => {
      unowned var descr = row.selected_descriptor;
      chunk_child.parameters = descr.adapt_parameters (chunk_child.parameters);
    });
  }

  public void add (Gtk.Widget widget) {
    this.group.add (widget);
  }
}

public class Contacts.BirthdayEditor : Adw.Dialog {

  private unowned Gtk.SpinButton day_spin;
  private unowned Gtk.DropDown month_dropdown;
  private unowned Gtk.SpinButton year_spin;

  public bool is_set { get; set; default = false; }

  public signal void changed ();

  construct {
    var toolbar_view = new Adw.ToolbarView ();
    this.child = toolbar_view;

    // The grid that will contain the Y/M/D fields
    var grid = new Gtk.Grid ();
    grid.column_spacing = 12;
    grid.row_spacing = 12;
    grid.add_css_class ("contacts-editor-birthday");
    toolbar_view.content = grid;

    // Day
    var d_spin = new Gtk.SpinButton.with_range (1.0, 31.0, 1.0);
    d_spin.digits = 0;
    d_spin.numeric = true;
    this.day_spin = d_spin;

    // Month
    string[] months = {};
    var january = new DateTime.local (1, 1, 1, 1, 1, 1);
    for (int i = 0; i < 12; i++) {
      var month = january.add_months (i);
      months += month.format ("%B");
    }
    months += null;

    var m_dropdown = new Gtk.DropDown.from_strings (months);
    m_dropdown.hexpand = true;
    this.month_dropdown = m_dropdown;

    // Year
    var y_spin = new Gtk.SpinButton.with_range (1800, 3000, 1);
    y_spin.set_digits (0);
    y_spin.numeric = true;
    this.year_spin = y_spin;

    // Create grid and labels
    Gtk.Label day = new Gtk.Label (_("Day"));
    day.set_halign (Gtk.Align.END);
    grid.attach (day, 0, 0);
    grid.attach (day_spin, 1, 0);
    Gtk.Label month = new Gtk.Label (_("Month"));
    month.set_halign (Gtk.Align.END);
    grid.attach (month, 0, 1);
    grid.attach (month_dropdown, 1, 1);
    Gtk.Label year = new Gtk.Label (_("Year"));
    year.set_halign (Gtk.Align.END);
    grid.attach (year, 0, 2);
    grid.attach (year_spin, 1, 2);

    // Headerbar
    var titlebar = new Adw.HeaderBar ();
    titlebar.show_end_title_buttons = false;
    titlebar.show_start_title_buttons = false;
    toolbar_view.add_top_bar (titlebar);

    var cancel_button = new Gtk.Button.with_mnemonic (_("_Cancel"));
    cancel_button.can_shrink = true;
    cancel_button.action_name = "window.close";
    titlebar.pack_start (cancel_button);

    var ok_button = new Gtk.Button.with_mnemonic (_("_Set"));
    ok_button.can_shrink = true;
    ok_button.add_css_class ("suggested-action");
    ok_button.clicked.connect ((b) => {
      this.is_set = true;
      changed ();
      close ();
    });
    titlebar.pack_end (ok_button);

    set_title (_("Change Birthday"));
  }

  public BirthdayEditor (DateTime? birthday) {
    // Don't forget to change to local timezone first
    var bday_local = (birthday != null)? birthday.to_local () : new DateTime.now_local ();
    this.day_spin.set_value ((double) bday_local.get_day_of_month ());
    this.month_dropdown.selected = bday_local.get_month () - 1;
    this.year_spin.set_value ((double) bday_local.get_year ());

    update_date ();
    month_dropdown.notify["selected"].connect ((obj, pspec) => {
      update_date ();
    });
    year_spin.value_changed.connect (() => {
      update_date ();
    });
  }

  /** Returns the selected birthday (in UTC timezone) */
  public GLib.DateTime get_birthday () {
    return new GLib.DateTime.local (year_spin.get_value_as_int (),
                                    (int) month_dropdown.selected + 1,
                                    day_spin.get_value_as_int (),
                                    0, 0, 0).to_utc ();
  }

  private void update_date() {
    const uint[] month_of_31 = {3, 5, 8, 10};

    if (this.month_dropdown.selected in month_of_31) {
      this.day_spin.set_range (1, 30);
    } else if (this.month_dropdown.selected == 1) {
      if (this.year_spin.get_value_as_int () % 400 == 0 ||
          (this.year_spin.get_value_as_int () % 4 == 0 &&
           this.year_spin.get_value_as_int () % 100 != 0)) {
        this.day_spin.set_range (1, 29);
      } else {
        this.day_spin.set_range (1, 28);
      }
    } else {
      this.day_spin.set_range (1, 31);
    }
  }
}

public class Contacts.AddressEditor : Gtk.Widget {

  private const string[] postal_element_props = {
    "street", "extension", "locality", "region", "postal_code", "po_box", "country"
  };
  private static string[] postal_element_names = {
    _("Street"), _("Extension"), _("City"), _("State/Province"), _("Zip/Postal Code"), _("PO box"), _("Country")
  };

  public signal void changed ();

  construct {
    var box_layout = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
    set_layout_manager (box_layout);

    add_css_class ("contacts-editor-address");
  }

  public AddressEditor (Address address) {
    for (int i = 0; i < postal_element_props.length; i++) {
      var entry = new Gtk.Entry ();
      entry.hexpand = true;
      entry.placeholder_text = AddressEditor.postal_element_names[i];
      entry.add_css_class ("flat");

      unowned var prop_name = AddressEditor.postal_element_props[i];
      address.address.bind_property (prop_name, entry, "text",
                                     BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

      entry.set_parent (this);
    }
  }

  public override void dispose () {
    unowned Gtk.Widget? child = null;
    while ((child = get_first_child ()) != null)
      child.unparent ();
    base.dispose ();
  }
}
