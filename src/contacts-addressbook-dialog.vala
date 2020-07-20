/*
 * Copyright (C) 2020 Niels De Graef <nielsdegraef@gmail.com>
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

public class Contacts.AddressbookDialog : Gtk.Dialog {

  private AccountsList accounts_list;

  public AddressbookDialog (Store contacts_store, Gtk.Window? window) {
    Object(
      transient_for: window,
      title: _("Change Address Book"),
      use_header_bar: 1
    );

    add_buttons (_("Change"), Gtk.ResponseType.OK,
                 _("Cancel"), Gtk.ResponseType.CANCEL);

    var content_area = get_content_area () as Gtk.Box;
    content_area.border_width = 0;

    var ok_button = get_widget_for_response (Gtk.ResponseType.OK);
    ok_button.sensitive = false;
    ok_button.get_style_context ().add_class ("suggested-action");

    var scrolled_window = new Gtk.ScrolledWindow (null, null);
    scrolled_window.expand = true;
    scrolled_window.height_request = 300;
    scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
    scrolled_window.propagate_natural_height = true;
    content_area.add (scrolled_window);

    var clamp = new Hdy.Clamp ();
    clamp.margin_top = 32;
    clamp.margin_bottom = 32;
    clamp.margin_start = 12;
    clamp.margin_end = 12;
    clamp.maximum_size = 400;
    scrolled_window.add (clamp);

    var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
    box.valign = Gtk.Align.START;
    clamp.add (box);

    var explanation_label = new Gtk.Label (_("New contacts will be added to the selected address book.\nYou are able to view and edit contacts from other address books."));
    explanation_label.xalign = 0;
    explanation_label.wrap = true;
    box.add (explanation_label);

    this.accounts_list = new AccountsList (contacts_store);
    this.accounts_list.update_contents (true);

    ulong active_button_once = 0;
    active_button_once = this.accounts_list.account_selected.connect (() => {
      ok_button.sensitive = true;
      this.accounts_list.disconnect (active_button_once);
    });

    contacts_store.backend_store.backend_available.connect (() => {
        this.accounts_list.update_contents (true);
    });

    box.add (this.accounts_list);

    show_all ();
  }

  public override void response (int response) {
    if (response != Gtk.ResponseType.OK)
      return;

    var e_store = this.accounts_list.selected_store as Edsf.PersonaStore;
    if (e_store != null) {
      eds_source_registry.set_default_address_book (e_store.source);
      var settings = new GLib.Settings ("org.freedesktop.folks");
      settings.set_string ("primary-store", "eds:%s".printf(e_store.id));
    }
  }
}
