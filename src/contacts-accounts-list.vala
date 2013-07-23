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

public class Contacts.AccountsGrid : Frame {
  ListBox accounts_view;
  ListBoxRow last_selected_row;
  Button add_account_button;

  public PersonaStore selected_store;

  public AccountsGrid () {
    selected_store = null;

    accounts_view = new ListBox ();
    accounts_view.set_selection_mode (SelectionMode.BROWSE);
    accounts_view.set_size_request (400, -1);
    accounts_view.set_activate_on_single_click (true);

    var scrolled = new ScrolledWindow(null, null);
    scrolled.set_size_request (-1, 200);
    scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
    scrolled.set_shadow_type (ShadowType.NONE);
    scrolled.add (accounts_view);

    var toolbar = new Toolbar ();
    toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);

    add_account_button = new Button.with_label (_("Add an Online Account"));
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

    var spacer = new SeparatorToolItem ();
    spacer.set_draw (false);
    spacer.set_expand (true);
    toolbar.add (spacer);

    var item = new ToolItem ();
    item.add (add_account_button);
    toolbar.add (item);

    spacer = new SeparatorToolItem ();
    spacer.set_draw (false);
    spacer.set_expand (true);
    toolbar.add (spacer);

    var box = new Grid ();
    box.set_orientation (Orientation.VERTICAL);
    box.add (scrolled);
    box.add (toolbar);

    add (box);
    show_all ();

    update_contents ();
  }

  public void update_contents () {
    PersonaStore local_store = null;
    foreach (var persona_store in App.get_eds_address_books ()) {
      if (persona_store.id == "system-address-book") {
        local_store = persona_store;
        continue;
      }
      var source = (persona_store as Edsf.PersonaStore).source;
      var parent_source = eds_source_registry.ref_source (source.parent);

      var provider_name = Contact.format_persona_store_name (persona_store);

      var row_data = new Grid ();
      row_data.set_data ("store", persona_store);
      row_data.margin = 12;

      var provider_label = new Label (provider_name);
      row_data.add (provider_label);

      var account_name = parent_source.display_name;
      var account_label = new Label (account_name);
      account_label.set_halign (Align.END);
      account_label.set_hexpand (true);
      account_label.get_style_context ().add_class ("dim-label");
      row_data.add (account_label);

      accounts_view.add (row_data);

      if (persona_store == App.app.contacts_store.aggregator.primary_store) {
        var row = row_data.get_parent () as ListBoxRow;
        accounts_view.select_row (row);
      }
    }

    var local_data = new Grid ();
    local_data.margin = 12;
    local_data.set_data ("store", local_store);
    var local_label = new Label (_("Keep contacts on this computer only"));
    local_data.add (local_label);
    accounts_view.add (local_data);
    if (local_store == App.app.contacts_store.aggregator.primary_store) {
      var row = local_data.get_parent () as ListBoxRow;
      accounts_view.select_row (row);
    }

    accounts_view.set_header_func ((row) => {
        if (row.get_header () == null)
          row.set_header (new Separator (Orientation.HORIZONTAL));
      });

    accounts_view.row_selected.connect ((row) => {
        if (row == null)
          return;

        var row_data = (row as Bin).get_child ();
        var account_label = (row_data as Grid).get_child_at (1, 0);
        if (account_label != null)
          account_label.get_style_context ().remove_class ("dim-label");

        if (last_selected_row != null) {
          var last_row_data = (last_selected_row as Bin).get_child ();
          var last_account_label = (last_row_data as Grid).get_child_at (1, 0);
          if (last_account_label != null)
            last_account_label.get_style_context ().add_class ("dim-label");
        }

        last_selected_row = row;

        selected_store = row_data.get_data<PersonaStore> ("store");
      });
  }
}