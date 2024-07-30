/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * The SetupWindow is the window that is shown to the user when they run
 * Contacts for the first time. It asks the user to setup a primary address
 * book.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-setup-window.ui")]
public class Contacts.SetupWindow : Adw.ApplicationWindow {

  [GtkChild]
  private unowned Adw.Clamp clamp;

  [GtkChild]
  private unowned Gtk.Button setup_done_button;

  private AccountsList accounts_list;

  /**
   * Fired after the user has successfully performed the setup proess.
   */
  public signal void setup_done (Edsf.PersonaStore selected_address_book);

  public SetupWindow (App app, Store store) {
    Object (application: app, icon_name: Config.APP_ID);

    // Setup the list of address books
    this.accounts_list = new AccountsList (store);
    this.clamp.set_child (this.accounts_list);

    this.accounts_list.notify["selected-store"].connect ((obj, pspec) => {
      this.setup_done_button.sensitive = (this.accounts_list.selected_store != null);
    });

    // In case of a badly configured system, there will be 0 address books and
    // as a user there's no way to know why that might happen, so at least put
    // a warning log message. Make sure we do give Backends some time to come
    // up
    Timeout.add_seconds (5, () => {
      if (store.address_books.get_n_items () == 0)
        warning ("No address books were found on the system. Are you sure evolution-data-server is running?");
      return Source.REMOVE;
    });

    // Make sure we emit a signal when setup is complete
    this.setup_done_button.clicked.connect (() => {
      setup_done ((Edsf.PersonaStore) this.accounts_list.selected_store);
    });

    // Make visible when we're using a nightly build
    if (Config.PROFILE == "development")
        add_css_class ("devel");
  }
}
