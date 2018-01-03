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

using Gee;
using Gtk;
using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-setup-window.ui")]
public class Contacts.SetupWindow : Gtk.ApplicationWindow {
  [GtkChild]
  private Grid content;

  [GtkChild]
  private Button setup_done_button;

  private AccountsList setup_accounts_list;

  /**
   * Fired after the user has succesfully performed the setup proess.
   */
  public signal void setup_done (Edsf.PersonaStore selected_address_book);

  public SetupWindow (App app, Store store) {
    Object (application: app);
    this.setup_accounts_list = new AccountsList (store);
    this.setup_accounts_list.hexpand = true;
    this.setup_accounts_list.halign = Align.CENTER;
    this.setup_accounts_list.show ();
    this.content.add (this.setup_accounts_list);

    // Listen for changes
    store.eds_persona_store_changed.connect  ( () => {
        this.setup_accounts_list.update_contents (false);
      });

    ulong id2 = 0;
    id2 = this.setup_accounts_list.account_selected.connect (() => {
        this.setup_done_button.set_sensitive (true);
        this.setup_accounts_list.disconnect (id2);
      });

    fill_accounts_list (store);

    // TODO make this a clickbable listbox
    // TODO if accountslist is empty: don't show accountslist 
    GLib.List<Goa.Provider>? providers = null;
    Goa.Provider.get_all ( (obj, res) => {
        try {
          Goa.Provider.get_all_finish (out providers, res);
        } catch (Error e) {
          warning ("Couldn't get list of providers!");
        }

        foreach (var provider in providers)
          if (Goa.ProviderFeatures.CONTACTS in provider.get_provider_features ())
            warning ("Found contacts provider \"%s\"", provider.get_provider_name ());
      });

    this.setup_done_button.clicked.connect (() => {
        var selected_store = this.setup_accounts_list.selected_store as Edsf.PersonaStore;
        setup_done (selected_store);
      });
  }

  private void fill_accounts_list (Store store) {
    if (store.is_prepared) {
      this.setup_accounts_list.update_contents (false);
      return;
    }

    store.prepared.connect ( () => {
        this.setup_accounts_list.update_contents (false);
      });
  }
}
