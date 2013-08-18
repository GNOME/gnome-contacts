/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 8 -*- */
/*
 * Copyright (C) 2011 Erick Pérez Castellanos <erick.red@gmail.com>
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

public class Contacts.AccountsList : Grid {
  ListBox accounts_view;
  ListBoxRow last_selected_row;
  Button add_account_button;

  public PersonaStore selected_store;

  public signal void account_selected ();

  public AccountsList () {
    set_orientation (Orientation.VERTICAL);
    set_row_spacing (22);

    selected_store = null;

    accounts_view = new ListBox ();
    accounts_view.set_selection_mode (SelectionMode.NONE);
    accounts_view.set_size_request (400, -1);
    accounts_view.set_header_func (update_header_func);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_min_content_height (260);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_shadow_type (ShadowType.IN);
    scrolled.add (accounts_view);

    add_account_button = new Button.with_label (_("Online Accounts"));
    add_account_button.get_style_context ().add_class (STYLE_CLASS_RAISED);
    add_account_button.get_child ().margin_left = 6;
    add_account_button.get_child ().margin_right = 6;
    add_account_button.get_child ().margin_top = 3;
    add_account_button.get_child ().margin_bottom = 3;
    add_account_button.clicked.connect (() => {
        try {
          Process.spawn_command_line_async ("gnome-control-center online-accounts");
        }
        catch (Error e) {
          // TODO: Show error dialog
        }
      });

    add (scrolled);
    add (add_account_button);

    show_all ();

    /* signal handling */
    accounts_view.row_activated.connect (row_activated);
  }

  private void row_activated (ListBoxRow? row) {
    if (row == null)
      return;

    var row_data = (row as Bin).get_child () as Grid;
    var checkmark = new Image.from_icon_name ("object-select-symbolic", IconSize.MENU);
    checkmark.margin_right = 12;
    checkmark.set_valign (Align.CENTER);
    checkmark.set_halign (Align.END);
    checkmark.set_vexpand (true);
    checkmark.set_hexpand (true);
    checkmark.show ();
    row_data.attach (checkmark, 2, 0, 1, 2);

    if (last_selected_row != null) {
      var last_row_data = (last_selected_row as Bin).get_child () as Grid;
      last_row_data.get_child_at (2, 0).destroy ();
    }

    last_selected_row = row;

    selected_store = row_data.get_data<PersonaStore> ("store");

    account_selected ();
  }

  private void update_header_func (ListBoxRow row, ListBoxRow? before) {
    if (row.get_header () == null) {
      row.set_header (new Separator (Orientation.HORIZONTAL));
      return;
    }
    row.set_header (null);
  }

  public void update_contents (bool select_active) {
    foreach (var child in accounts_view.get_children ()) {
      child.destroy ();
    }

    PersonaStore local_store = null;
    foreach (var persona_store in App.get_eds_address_books ()) {
      if (persona_store.id == "system-address-book") {
        local_store = persona_store;
        continue;
      }
      var source = (persona_store as Edsf.PersonaStore).source;
      var parent_source = eds_source_registry.ref_source (source.parent);

      var provider_name = Contact.format_persona_store_name (persona_store);

      var source_account_id = "";
      if (parent_source.has_extension (E.SOURCE_EXTENSION_GOA)) {
        var goa_source_ext = parent_source.get_extension (E.SOURCE_EXTENSION_GOA) as E.SourceGoa;
        source_account_id = goa_source_ext.account_id;
      }

      var row_data = new Grid ();
      row_data.set_data ("store", persona_store);
      row_data.margin = 6;
      row_data.margin_left = 5;
      row_data.set_row_spacing (2);
      row_data.set_column_spacing (10);

      if (source_account_id != "") {
        var provider_image = Contacts.get_icon_for_goa_account (source_account_id);
        row_data.attach (provider_image, 0, 0, 1, 2);
      } else {
        var provider_image = new Image.from_icon_name ("drive-harddisk-system-symbolic",
                                                       IconSize.DIALOG);
        row_data.attach (provider_image, 0, 0, 1, 2);
      }

      var provider_label = new Label (provider_name);
      provider_label.set_halign (Align.START);
      provider_label.set_hexpand (true);
      provider_label.set_valign (Align.END);
      row_data.attach (provider_label, 1, 0, 1, 1);

      var account_name = parent_source.display_name;
      var account_label = new Label (account_name);
      account_label.set_halign (Align.START);
      account_label.set_hexpand (true);
      account_label.set_valign (Align.START);
      account_label.get_style_context ().add_class ("dim-label");
      row_data.attach (account_label, 1, 1, 1, 1);

      accounts_view.add (row_data);

      if (select_active &&
          persona_store == App.app.contacts_store.aggregator.primary_store) {
        var row = row_data.get_parent () as ListBoxRow;
        row_activated (row);
      }
    }

    var local_data = new Grid ();
    local_data.margin = 6;
    local_data.margin_left = 5;
    local_data.set_column_spacing (10);
    local_data.set_data ("store", local_store);
    var provider_image = new Image.from_icon_name ("drive-harddisk-system-symbolic",
                                                   IconSize.DIALOG);
    local_data.add (provider_image);
    var local_label = new Label (_("Local Address Book"));
    local_data.add (local_label);
    accounts_view.add (local_data);
    if (select_active &&
        local_store == App.app.contacts_store.aggregator.primary_store) {
      var row = local_data.get_parent () as ListBoxRow;
      row_activated (row);
    }

    accounts_view.show_all ();
  }
}