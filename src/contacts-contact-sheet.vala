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

using Folks;

public class Contacts.ContactSheetRow : Adw.ActionRow {

  construct {
    this.title_selectable = true;
  }

  public ContactSheetRow (string property_name, string title, string? subtitle = null) {
    unowned var icon_name = Utils.get_icon_name_for_property (property_name);
    if (icon_name != null) {
      var icon = new Gtk.Image.from_icon_name (icon_name);
      icon.add_css_class ("contacts-property-icon");
      icon.tooltip_text = Utils.get_display_name_for_property (property_name);
      this.add_prefix (icon);
    }

    this.title = Markup.escape_text (title);

    if (subtitle != null)
      this.subtitle = subtitle;
  }

  public Gtk.Button add_button (string icon) {
    var button = new Gtk.Button.from_icon_name (icon);
    button.valign = Gtk.Align.CENTER;
    button.add_css_class ("flat");
    this.add_suffix (button);
    return button;
  }
}

/**
 * The contact sheet displays the actual information of a contact.
 *
 * (Note: to edit a contact, use the {@link ContactEditor} instead.
 */
public class Contacts.ContactSheet : Gtk.Grid {

  private int last_row = 0;
  private unowned Individual individual;
  private unowned Store store;

  private const string[] SORTED_PROPERTIES = {
    "email-addresses",
    "phone-numbers",
    "im-addresses",
    "roles",
    "urls",
    "nickname",
    "birthday",
    "postal-addresses",
    "notes"
  };

  construct {
    this.add_css_class ("contacts-sheet");
  }

  public ContactSheet (Individual individual, Store store) {
    this.individual = individual;
    this.store = store;

    this.individual.notify.connect (update);
    this.individual.personas_changed.connect (update);
    store.quiescent.connect (update);

    update ();
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

  // Helper function that attaches a set of property rows to our grid
  private void attach_rows (GLib.List<Gtk.ListBoxRow>? rows) {
    if (rows == null)
      return;

    var group = new Adw.PreferencesGroup ();
    group.add_css_class ("contacts-sheet-property");

    foreach (unowned var row in rows)
      group.add (row);

    this.attach (group, 0, this.last_row, 3, 1);
    this.last_row++;
  }

  private void attach_row (Gtk.ListBoxRow row) {
    var rows = new GLib.List<Gtk.ListBoxRow> ();
    rows.prepend (row);
    this.attach_rows (rows);
  }

  private void update () {
    this.last_row = 0;

    // Remove all fields
    unowned var child = get_first_child ();
    while (child != null) {
      unowned var next = child.get_next_sibling ();
      remove (child);
      child = next;
    }

    var header = create_header ();
    this.attach (header, 0, 0, 1, 1);

    this.last_row++;

    var personas = Utils.personas_as_list_model (individual);
    var personas_filtered = new Gtk.FilterListModel (personas, new PersonaFilter ());
    var personas_sorted = new Gtk.SortListModel (personas_filtered, new PersonaSorter ());

    for (int i = 0; i < personas_sorted.get_n_items (); i++) {
      var persona = (Persona) personas_sorted.get_item (i);
      int persona_store_pos = this.last_row;

      if (i > 0) {
        this.attach (create_persona_store_label (persona), 0, this.last_row, 3);
        this.last_row++;
      }

      foreach (unowned var prop in SORTED_PROPERTIES)
        add_row_for_property (persona, prop);

      // Nothing to show in the persona: don't mention it
      bool is_empty_persona = (this.last_row == persona_store_pos + 1);
      if (i > 0 && is_empty_persona) {
        this.remove_row (persona_store_pos);
        this.last_row--;
      }
    }
  }

  private Gtk.Widget create_header () {
    var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 18);
    header.add_css_class ("contacts-sheet-header");

    var image_frame = new Avatar (PROFILE_SIZE, this.individual);
    image_frame.vexpand = false;
    image_frame.valign = Gtk.Align.START;
    header.append (image_frame);

    var name_label = new Gtk.Label ("");
    name_label.label = this.individual.display_name;
    name_label.hexpand = true;
    name_label.xalign = 0f;
    name_label.wrap = true;
    name_label.wrap_mode = WORD_CHAR;
    name_label.lines = 4;
    name_label.width_chars = 10;
    name_label.selectable = true;
    name_label.can_focus = false;
    name_label.add_css_class ("title-1");
    header.append (name_label);

    return header;
  }

  private void add_row_for_property (Persona persona, string property) {
    switch (property) {
      case "email-addresses":
        add_emails (persona, property);
        break;
      case "phone-numbers":
        add_phone_nrs (persona, property);
        break;
      case "im-addresses":
        add_im_addresses (persona, property);
        break;
      case "urls":
        add_urls (persona, property);
        break;
      case "nickname":
        add_nickname (persona, property);
        break;
      case "birthday":
        add_birthday (persona, property);
        break;
      case "notes":
        add_notes (persona, property);
        break;
      case "postal-addresses":
        add_postal_addresses (persona, property);
        break;
      case "roles":
        add_roles (persona, property);
        break;
      default:
        debug ("Unsupported property: %s", property);
        break;
    }
  }

  private void add_roles (Persona persona, string property) {
    unowned var details = persona as RoleDetails;
    if (details == null)
      return;

    var roles = Utils.fields_to_sorted (details.roles);
    var rows = new GLib.List<Gtk.ListBoxRow> ();
    for (uint i = 0; i < roles.get_n_items (); i++) {
      var role = (RoleFieldDetails) roles.get_item (i);

      if (role.value.is_empty ())
        continue;

      var role_str = "";
      if (role.value.title != "") {
        if (role.value.organisation_name != "")
          // TRANSLATORS: "$ROLE at $ORGANISATION", e.g. "CEO at Linux Inc."
          role_str = _("%s at %s").printf (role.value.title, role.value.organisation_name);
        else
          role_str = role.value.title;
      } else {
          role_str = role.value.organisation_name;
      }

      var row = new ContactSheetRow (property, role_str);

      //XXX if no role: set "Organisation" tool tip
      rows.append (row);
    }

    this.attach_rows (rows);
  }

  private void add_emails (Persona persona, string property) {
    unowned var details = persona as EmailDetails;
    if (details == null)
      return;

    var emails = Utils.fields_to_sorted (details.email_addresses);
    var rows = new GLib.List<Gtk.ListBoxRow> ();
    for (uint i = 0; i < emails.get_n_items (); i++) {
      var email = (EmailFieldDetails) emails.get_item (i);

      if (email.value == "")
        continue;

      var row = new ContactSheetRow (property,
                                     email.value,
                                     TypeSet.email.format_type (email));

      var button = row.add_button ("mail-send-symbolic");
      button.tooltip_text = _("Send an email to %s".printf (email.value));
      button.clicked.connect (() => {
        Utils.compose_mail ("%s <%s>".printf(this.individual.display_name, email.value));
      });

      rows.append (row);
    }

    this.attach_rows (rows);
  }

  private void add_phone_nrs (Persona persona, string property) {
    unowned var phone_details = persona as PhoneDetails;
    if (phone_details == null)
      return;

    var phones = Utils.fields_to_sorted (phone_details.phone_numbers);
    var rows = new GLib.List<Gtk.ListBoxRow> ();
    for (uint i = 0; i < phones.get_n_items (); i++) {
      var phone = (PhoneFieldDetails) phones.get_item (i);

      if (phone.value == "")
        continue;

      var row = new ContactSheetRow (property,
                                     phone.value,
                                     TypeSet.phone.format_type (phone));

#if HAVE_TELEPATHY
      if (this.store.caller_account != null) {
        var button = row.add_button ("call-start-symbolic");
        button.tooltip_text = _("Start a call");
        button.clicked.connect (() => {
          Utils.start_call (phone.value, this.store.caller_account);
        });
      }
#endif

      rows.append (row);
    }

    this.attach_rows (rows);
  }

  private void add_im_addresses (Persona persona, string property) {
    // NOTE: We _could_ enable this again, but only for specific services.
    // Right now, this just enables a million "Windows Live Messenger" and
    // "Jabber", ... fields, which are all resting in their respective coffins.
#if 0
    unowned var im_details = persona as ImDetails;
    if (im_details == null)
      return;

    var rows = new GLib.List<Gtk.ListBoxRow> ();
    foreach (var protocol in im_details.im_addresses.get_keys ()) {
      foreach (var id in im_details.im_addresses[protocol]) {
        var row = new ContactSheetRow (property,
                                       id.value,
                                       ImService.get_display_name (protocol));
        rows.append (row);
      }
    }

    this.attach_rows (rows);
#endif
  }

  private void add_urls (Persona persona, string property) {
    unowned var url_details = persona as UrlDetails;
    if (url_details == null)
      return;

    var rows = new GLib.List<Gtk.ListBoxRow> ();
    var urls = Utils.fields_to_sorted (url_details.urls);
    for (uint i = 0; i < urls.get_n_items (); i++) {
      var url = (UrlFieldDetails) urls.get_item (i);

      if (url.value == "")
        continue;

      var row = new ContactSheetRow (property, url.value);

      var button = row.add_button ("external-link-symbolic");
      button.tooltip_text = _("Visit website");
      button.clicked.connect (() => {
        unowned var window = button.get_root () as MainWindow;
        if (window == null)
          return;

        // FIXME: use show_uri_full so we can show errors
        Gtk.show_uri (window,
                      fallback_to_https (url.value),
                      Gdk.CURRENT_TIME);
      });

      rows.append (row);
    }

    this.attach_rows (rows);
  }

  // When the url doesn't contain a scheme we fallback to http
  // We are sure that the url is a webaddress but GTK falls back to opening a file
  private string fallback_to_https (string url) {
    string scheme = Uri.parse_scheme (url);
    if (scheme == null)
      return "https://" + url;
    return url;
  }

  private void add_nickname (Persona persona, string property) {
    unowned var name_details = persona as NameDetails;
    if (name_details == null || name_details.nickname == "")
      return;

    var row = new ContactSheetRow (property, name_details.nickname);
    this.attach_row (row);
  }

  private void add_birthday (Persona persona, string property) {
    unowned var birthday_details = persona as BirthdayDetails;
    if (birthday_details == null || birthday_details.birthday == null)
      return;

    var birthday_str = birthday_details.birthday.to_local ().format ("%x");

    // Compare month and date so we can put a reminder
    string? subtitle = null;
    int bd_m, bd_d, now_m, now_d;
    birthday_details.birthday.to_local ().get_ymd (null, out bd_m, out bd_d);
    new DateTime.now_local ().get_ymd (null, out now_m, out now_d);

    if (bd_m == now_m && bd_d == now_d) {
      subtitle = _("Their birthday is today! 🎉");
    }

    var row = new ContactSheetRow (property, birthday_str, subtitle);
    this.attach_row (row);
  }

  private void add_notes (Persona persona, string property) {
    unowned var note_details = persona as NoteDetails;
    if (note_details == null)
      return;

    var rows = new GLib.List<Gtk.ListBoxRow> ();
    foreach (var note in note_details.notes) {
      if (note.value == "")
        continue;

      var row = new ContactSheetRow (property, note.value);
      rows.append (row);
    }

    this.attach_rows (rows);
  }

  private void add_postal_addresses (Persona persona, string property) {
    unowned var addr_details = persona as PostalAddressDetails;
    if (addr_details == null)
      return;

    // Check outside of the loop if we have a "maps:" URI handler
    var appinfo = AppInfo.get_default_for_uri_scheme ("maps");
    var map_uris_supported = (appinfo != null);
    debug ("Opening 'maps:' URIs supported: %s", map_uris_supported.to_string ());

    var rows = new GLib.List<Gtk.ListBoxRow> ();
    foreach (var addr in addr_details.postal_addresses) {
      if (addr.value.is_empty ())
        continue;

      var row = new ContactSheetRow (property,
                                     string.joinv ("\n", Utils.format_address (addr.value)),
                                     TypeSet.general.format_type (addr));

      if (map_uris_supported) {
        var button = row.add_button ("map-symbolic");
        button.tooltip_text = _("Show on the map");
        button.clicked.connect (() => {
          unowned var window = button.get_root () as MainWindow;
          if (window == null)
            return;

          var uri = Utils.create_maps_uri (addr.value);
          // FIXME: use show_uri_full so we can show errors
          Gtk.show_uri (window, uri, Gdk.CURRENT_TIME);
        });
      }

      rows.append (row);
    }

    this.attach_rows (rows);
  }
}
