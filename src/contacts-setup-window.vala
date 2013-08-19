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

public class Contacts.SetupWindow : Gtk.Window {
  public bool succeeded;
  private ulong source_list_changed_id;
  Button done_button;

  private void select_source (E.Source source) {
    eds_source_registry.set_default_address_book (source);
    succeeded = true;
    App.app.settings.set_boolean ("did-initial-setup", true);
    destroy ();
  }

  public SetupWindow () {
    this.set_default_size (640, 480);

    var titlebar = new HeaderBar ();
    titlebar.set_title (_("Contacts Setup"));
    set_titlebar (titlebar);

    var cancel_button = new Button.with_label (_("Cancel"));
    cancel_button.get_child ().margin = 3;
    cancel_button.get_child ().margin_left = 6;
    cancel_button.get_child ().margin_right = 6;
    titlebar.pack_start (cancel_button);
    cancel_button.clicked.connect ( (button) => {
	this.destroy ();
      });

    /* hack to avoid accounts_list getting the focus and
     * triggering row_selected signal */
    cancel_button.grab_focus ();

    done_button = new Button.with_label (_("Done"));
    done_button.get_child ().margin = 3;
    done_button.get_child ().margin_left = 6;
    done_button.get_child ().margin_right = 6;
    done_button.set_sensitive (false);
    titlebar.pack_end (done_button);

    titlebar.show_all ();

    var grid = new Grid ();
    grid.set_orientation (Orientation.VERTICAL);
    grid.set_border_width (24);
    grid.set_row_spacing (24);
    this.add (grid);

    var l = new Label (_("Please select your primary contacts account"));
    l.set_halign (Align.CENTER);
    grid.add (l);

    var accounts_list = new AccountsList ();
    accounts_list.set_hexpand (true);
    accounts_list.set_halign (Align.CENTER);
    accounts_list.update_contents (false);

    grid.add (accounts_list);

    source_list_changed_id = App.app.contacts_store.eds_persona_store_changed.connect  ( () => {
    	accounts_list.update_contents (false);
      });

    accounts_list.account_selected.connect (() => {
	done_button.set_sensitive (true);
      });

    done_button.clicked.connect ( (button) => {
	var e_store = accounts_list.selected_store as Edsf.PersonaStore;

	select_source (e_store.source);
      });

    grid.show_all ();
  }

  public override void destroy () {
    if (source_list_changed_id != 0) {
      App.app.contacts_store.disconnect (source_list_changed_id);
      source_list_changed_id = 0;
    }
    base.destroy ();
  }
}
