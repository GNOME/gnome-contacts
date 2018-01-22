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

public class Contacts.ContactSheet : Grid {

  Button add_row_with_button (ref int row, string label_value, string value) {
    var type_label = new Label (label_value);
    type_label.xalign = 1.0f;
    type_label.set_halign (Align.END);
    type_label.get_style_context ().add_class ("dim-label");
    attach (type_label, 0, row, 1, 1);

    var value_button = new Button.with_label (value);
    value_button.focus_on_click = false;
    value_button.relief = ReliefStyle.NONE;
    value_button.xalign = 0.0f;
    value_button.set_hexpand (true);
    attach (value_button, 1, row, 1, 1);
    row++;

    (value_button.get_child () as Label).set_ellipsize (Pango.EllipsizeMode.END);
    (value_button.get_child () as Label).wrap_mode = Pango.WrapMode.CHAR;

    return value_button;
  }

  void add_row_with_link_button (ref int row, string label_value, string value) {
    var type_label = new Label (label_value);
    type_label.xalign = 1.0f;
    type_label.set_halign (Align.END);
    type_label.get_style_context ().add_class ("dim-label");
    attach (type_label, 0, row, 1, 1);

    var value_button = new LinkButton (value);
    value_button.focus_on_click = false;
    value_button.relief = ReliefStyle.NONE;
    value_button.xalign = 0.0f;
    value_button.set_hexpand (true);
    attach (value_button, 1, row, 1, 1);
    row++;

    (value_button.get_child () as Label).set_ellipsize (Pango.EllipsizeMode.END);
    (value_button.get_child () as Label).wrap_mode = Pango.WrapMode.CHAR;
  }

  void add_row_with_label (ref int row, string label_value, string value) {
    var type_label = new Label (label_value);
    type_label.xalign = 1.0f;
    type_label.set_halign (Align.END);
    type_label.set_valign (Align.START);
    type_label.get_style_context ().add_class ("dim-label");
    attach (type_label, 0, row, 1, 1);

    var value_label = new Label (value);
    value_label.set_line_wrap (true);
    value_label.xalign = 0.0f;
    value_label.set_halign (Align.START);
    value_label.set_ellipsize (Pango.EllipsizeMode.END);
    value_label.wrap_mode = Pango.WrapMode.CHAR;
    value_label.set_selectable (true);

    /* FIXME: hardcode gap to match the button size */
    type_label.margin_top = 3;
    value_label.margin_start = 6;
    value_label.margin_top = 3;
    value_label.margin_bottom = 3;

    attach (value_label, 1, row, 1, 1);
    row++;
  }

  public ContactSheet () {
    set_row_spacing (12);
    set_column_spacing (16);
    set_orientation (Orientation.VERTICAL);
    get_style_context ().add_class ("contacts-contact-sheet");
  }

  public void update (Contact c) {
    var image_frame = new Avatar (PROFILE_SIZE, c);
    image_frame.set_vexpand (false);
    image_frame.set_valign (Align.START);
    attach (image_frame,  0, 0, 1, 3);

    var name_label = new Label (null);
    name_label.set_hexpand (true);
    name_label.set_halign (Align.START);
    name_label.set_valign (Align.CENTER);
    name_label.margin_start = 6;
    name_label.set_ellipsize (Pango.EllipsizeMode.END);
    name_label.xalign = 0.0f;
    name_label.set_selectable (true);

    c.keep_widget_uptodate (name_label, (w) => {
        (w as Label).set_markup (Markup.printf_escaped ("<span font='16'>%s</span>", c.individual.display_name));
      });
    attach (name_label,  1, 0, 1, 3);

    int i = 3;
    int last_store_position = 0;
    bool is_first_persona = true;

    var personas = c.get_personas_for_display ();
    /* Cause personas are sorted properly I can do this */
    foreach (var p in personas) {
      if (!is_first_persona) {
	var store_name = new Label("");
	store_name.set_markup (Markup.printf_escaped ("<span font='16px bold'>%s</span>",
						      Contact.format_persona_store_name_for_contact (p)));
	store_name.set_halign (Align.START);
	store_name.xalign = 0.0f;
	store_name.margin_start = 6;
	attach (store_name, 0, i, 3, 1);
	last_store_position = ++i;
      }

      var details = p as EmailDetails;
      if (details != null) {
	var emails = Contact.sort_fields<EmailFieldDetails>(details.email_addresses);
	foreach (var email in emails) {
	  var button = add_row_with_button (ref i, TypeSet.email.format_type (email), email.value);
	  button.clicked.connect (() => {
	      Utils.compose_mail ("%s <%s>".printf(c.individual.display_name, email.value));
	    });
	}
      }

      var phone_details = p as PhoneDetails;
      if (phone_details != null) {
	var phones = Contact.sort_fields<PhoneFieldDetails>(phone_details.phone_numbers);
	foreach (var phone in phones) {
#if HAVE_TELEPATHY
	  if (c.store != null && c.store.caller_account != null) {
	    var button = add_row_with_button (ref i, TypeSet.phone.format_type (phone), phone.value);
	    button.clicked.connect (() => {
            Utils.start_call (phone.value, c.store.caller_account);
	      });
	  } else {
	    add_row_with_label (ref i, TypeSet.phone.format_type (phone), phone.value);
	  }
#else
          add_row_with_label (ref i, TypeSet.phone.format_type (phone), phone.value);
#endif
	}
      }

#if HAVE_TELEPATHY
      var im_details = p as ImDetails;
      if (im_details != null) {
	foreach (var protocol in im_details.im_addresses.get_keys ()) {
	  foreach (var id in im_details.im_addresses[protocol]) {
	    if (p is Tpf.Persona) {
	      var button = add_row_with_button (ref i, Contact.format_im_service (protocol), id.value);
	      button.clicked.connect (() => {
		  var im_persona = c.find_im_persona (protocol, id.value);
		  if (im_persona != null) {
		    var type = im_persona.presence_type;
		    if (type != PresenceType.UNSET &&
			type != PresenceType.ERROR &&
			type != PresenceType.OFFLINE &&
			type != PresenceType.UNKNOWN) {
		      Utils.start_chat (c, protocol, id.value);
		    }
		  }
		});
	    }
	  }
	}
      }
#endif

      var url_details = p as UrlDetails;
      if (url_details != null) {
	foreach (var url in url_details.urls)
	  add_row_with_link_button (ref i, _("Website"), url.value);
      }

      var name_details = p as NameDetails;
      if (name_details != null) {
	if (is_set (name_details.nickname)) {
	  add_row_with_label (ref i, _("Nickname"), name_details.nickname);
	}
      }

      var birthday_details = p as BirthdayDetails;
      if (birthday_details != null) {
	if (birthday_details.birthday != null) {
	  add_row_with_label (ref i, _("Birthday"), birthday_details.birthday.to_local ().format ("%x"));
	}
      }

      var note_details = p as NoteDetails;
      if (note_details != null) {
	foreach (var note in note_details.notes) {
	  add_row_with_label (ref i, _("Note"), note.value);
	}
      }

      var addr_details = p as PostalAddressDetails;
      if (addr_details != null) {
        foreach (var addr in addr_details.postal_addresses) {
          var all_strs = string.joinv ("\n", Contact.format_address (addr.value));
          add_row_with_label (ref i, TypeSet.general.format_type (addr), all_strs);
        }
      }

      if (i != 3)
	is_first_persona = false;

      if (i == last_store_position) {
	get_child_at (0, i - 1).destroy ();
      }
    }

    show_all ();
  }

  public void clear () {
    foreach (var w in get_children ()) {
      w.destroy ();
    }
  }
}
