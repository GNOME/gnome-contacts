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

public class Contacts.LinkDialog : Dialog {
  // TODO: Remove later when bound in vala
  private static unowned string C_(string context, string msgid) {
    return GLib.dpgettext2 (Config.GETTEXT_PACKAGE, context, msgid);
  }

  private Contact contact;
  private Contact? selected_contact;
  private Entry filter_entry;
  private View view;
  private Grid list_grid;
  private Grid persona_grid;
  private uint filter_entry_changed_id;

  public signal void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation);
  
  private void update_contact () {
    // Remove previous personas
    foreach (var w in persona_grid.get_children ()) {
      w.destroy ();
    }

    if (selected_contact == null)
      return;

    var image_frame = new ContactFrame (Contact.SMALL_AVATAR_SIZE);
    contact.keep_widget_uptodate (image_frame, (w) => {
	(w as ContactFrame).set_image (selected_contact.individual, selected_contact);
      });
    image_frame.set_hexpand (false);
    persona_grid.attach (image_frame, 0, 0, 1, 2);

    var label = new Label ("");
    label.set_markup ("<span font='13'>" + selected_contact.display_name + "</span>");
    label.set_valign (Align.START);
    label.set_halign (Align.START);
    label.set_hexpand (false);
    label.xalign = 0.0f;
    label.set_ellipsize (Pango.EllipsizeMode.END);
    persona_grid.attach (label, 1, 0, 1, 1);

    label = new Label ("");
    label.set_markup ("<span font='9'>" +selected_contact.format_persona_stores () + "</span>");
    label.set_valign (Align.START);
    label.set_halign (Align.START);
    label.set_hexpand (true);
    label.xalign = 0.0f;
    label.set_ellipsize (Pango.EllipsizeMode.END);
    persona_grid.attach (label, 1, 1, 1, 1);

    if (contact.is_main) {
      var link_button = new Button.with_label (C_("contacts link action", "Link"));
      link_button.set_hexpand (false);
      link_button.set_valign (Align.CENTER);
      var bbox = new ButtonBox (Orientation.HORIZONTAL);
      bbox.add (link_button);
      persona_grid.attach (bbox, 2, 0, 1, 2);

      link_button.clicked.connect ( (button) => {
	var selected_contact_name = selected_contact.display_name;
	link_contacts.begin (contact, selected_contact, (obj, result) => {
	    var operation = link_contacts.end (result);
	    var undo_bar = new InfoBar.with_buttons (_("Undo"), ResponseType.APPLY, null);
	    undo_bar.set_message_type (MessageType.INFO);
	    var container = (undo_bar.get_content_area () as Container);
	    var message_label = new Label (_("%s linked to the contact").printf (selected_contact_name));
	    //TODO, do something smarter here.
	    message_label.set_ellipsize (Pango.EllipsizeMode.END);
	    container.add (message_label);
	    undo_bar.response.connect ( (response_id) => {
	      if (response_id == ResponseType.APPLY) {
		operation.undo ();
		undo_bar.destroy ();
	      }
	    });
	    Timeout.add (5000, () => {
	      undo_bar.destroy ();
	      return false;
	    });
	    list_grid.add (undo_bar);
	    undo_bar.show_all ();
	  });
      });
    }

    var grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_border_width (8);

    persona_grid.attach (grid, 0, 2, 3, 1);


    var emails = Contact.sort_fields<EmailFieldDetails>(selected_contact.individual.email_addresses);
    if (!emails.is_empty) {
      label = new Label (_("Email"));
      label.xalign = 0.0f;
      grid.add (label);
      foreach (var email in emails) {
	label = new Label (email.value);
	label.set_ellipsize (Pango.EllipsizeMode.END);
	label.xalign = 0.0f;
	grid.add (label);
      }
      label = new Label ("");
      label.xalign = 0.0f;
      grid.add (label);
    }

    var phone_numbers = Contact.sort_fields<PhoneFieldDetails>(selected_contact.individual.phone_numbers);
    if (!phone_numbers.is_empty) {
      label = new Label (_("Phone number"));
      label.xalign = 0.0f;
      grid.add (label);
      foreach (var phone_number in phone_numbers) {
	label = new Label (phone_number.value);
	label.set_ellipsize (Pango.EllipsizeMode.END);
	label.xalign = 0.0f;
	grid.add (label);
      }
    }

    persona_grid.show_all ();
  }

  public LinkDialog (Contact contact) {
    this.contact = contact;
    set_title (_("Link Contact"));
    set_transient_for (App.app.window);
    set_modal (true);
    if (contact.is_main)
      add_buttons (_("Close"), ResponseType.CLOSE, null);
    else {
      add_buttons (_("Cancel"), ResponseType.CANCEL, _("Link"), ResponseType.APPLY, null);
    }

    view = new View (contact.store, View.TextDisplay.STORES);
    view.hide_contact (contact);
    if (contact.is_main)
      view.set_show_subset (View.Subset.OTHER);
    else
      view.set_show_subset (View.Subset.ALL_SEPARATED);

    var matches = contact.store.aggregator.get_potential_matches (contact.individual, MatchResult.HIGH);
    foreach (var ind in matches.keys) {
      var c = Contact.from_individual (ind);
      if (c != null) {
	var result = matches.get (ind);
	view.set_custom_sort_prio (c, (int) result);
      }
    }

    var grid = new Grid ();
    grid.set_row_spacing (6);
    grid.set_column_homogeneous (true);
    var container = (get_content_area () as Container);
    grid.set_border_width (8);
    container.add (grid);

    var label = new Label ("");
    if (contact.is_main)
      label.set_markup (_("<span weight='bold'>Link contacts to %s</span>").printf (contact.display_name));
    else
      label.set_markup (_("<span weight='bold'>Select contact to link to</span>"));
    label.set_valign (Align.CENTER);
    label.set_halign (Align.CENTER);
    label.set_ellipsize (Pango.EllipsizeMode.END);
    grid.attach (label, 0, 0, 2, 1);

    var list_frame = new Frame (null);
    list_frame.get_style_context ().add_class ("contacts-list-frame");
    grid.attach (list_frame, 0, 1, 1, 1);

    list_grid = new Grid ();
    list_grid.set_size_request (315, -1);
    list_grid.set_hexpand (false);
    list_frame.add (list_grid);
    list_grid.set_orientation (Orientation.VERTICAL);

    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.set_vexpand (false);
    list_grid.add (toolbar);

    filter_entry = new Entry ();
    filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    filter_entry.changed.connect (filter_entry_changed);
    filter_entry.icon_press.connect (filter_entry_clear);

    var search_entry_item = new ToolItem ();
    search_entry_item.is_important = false;
    search_entry_item.set_expand (true);
    search_entry_item.add (filter_entry);
    toolbar.add (search_entry_item);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_min_content_width (310);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.add_with_viewport (view);
    list_grid.add (scrolled);
    view.set_focus_vadjustment (scrolled.get_vadjustment ());

    view.selection_changed.connect ( (c) => {
	selected_contact = c;
	update_contact ();
      });

    scrolled = new ScrolledWindow(null, null);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_vexpand (true);
    scrolled.set_hexpand (true);
    scrolled.set_shadow_type (ShadowType.NONE);
    grid.attach (scrolled, 1, 1, 1, 1);

    persona_grid = new Grid ();
    persona_grid.set_orientation (Orientation.VERTICAL);
    persona_grid.set_border_width (4);
    persona_grid.set_column_spacing (8);
    scrolled.add_with_viewport (persona_grid);

    response.connect ( (response_id) => {
      if (response_id == ResponseType.APPLY &&
          selected_contact != null) {
        link_contacts.begin (selected_contact, contact, (obj, result) => {
          var main_contact_name = selected_contact.display_name;
          var linked_contact_name = contact.display_name;
          var operation = link_contacts.end (result);
          this.contacts_linked (main_contact_name, linked_contact_name, operation);
          this.destroy ();
        });
      } else
        this.destroy ();

      this.hide ();
    });

    set_default_size (710, 510);
  }

  private void refilter () {
    string []? values;
    string str = filter_entry.get_text ();

    if (str.length == 0)
      values = null;
    else {
      str = Utils.canonicalize_for_search (str);
      values = str.split(" ");
    }

    view.set_filter_values (values);
  }

  private bool filter_entry_changed_timeout () {
    filter_entry_changed_id = 0;
    refilter ();
    return false;
  }

  private void filter_entry_changed (Editable editable) {
    if (filter_entry_changed_id != 0)
      Source.remove (filter_entry_changed_id);

    filter_entry_changed_id = Timeout.add (300, filter_entry_changed_timeout);

    if (filter_entry.get_text () == "")
      filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-find-symbolic");
    else
      filter_entry.set_icon_from_icon_name (EntryIconPosition.SECONDARY, "edit-clear-symbolic");
  }

  private void filter_entry_clear (EntryIconPosition position) {
    filter_entry.set_text ("");
  }
}
