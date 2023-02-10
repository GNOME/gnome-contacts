/*
 * Copyright (C) 2011 Erick Pérez Castellanos <erick.red@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * The AccountsList widget provides a way to list all the known address books
 * for a user, as well as providing a means of selecting a "primary" address
 * book, ie the address book that will be used to write the details of a
 * contact to.
 *
 * Internally, each "address book" is a {@link Folks.PersonaStore}.
 */
public class Contacts.AccountsList : Adw.PreferencesGroup {

  private Gtk.SingleSelection selection;

  private GenericArray<AddressbookRow> rows = new GenericArray<AddressbookRow> ();

  /** The selected PersonaStore (or null if none) */
  public PersonaStore? selected_store {
    get { return (PersonaStore) this.selection.selected_item; }
  }

  public AccountsList (Store contacts_store) {
    // We only list E-D-S address books here, so make a filter model
    var filter = new Gtk.CustomFilter ((item) => {
      unowned var store = (PersonaStore) item;
      return store.type_id == "eds";
    });
    var model = new Gtk.FilterListModel (contacts_store.address_books,
                                         (owned) filter);

    model.items_changed.connect (on_model_items_changed);
    on_model_items_changed (model, 0, 0, model.get_n_items ());

    // Setup the selection model for the primary address book
    this.selection = new Gtk.SingleSelection (null);
    this.selection.autoselect = false;
    this.selection.model = model;

    // Update the row when the selection model changes
    this.selection.selection_changed.connect ((sel, pos, n_items) => {
      for (uint i = pos; i < pos + n_items; i++) {
        this.rows[i].selected = this.selection.is_selected (i);
      }
      notify_property ("selected-store");
    });

    // Initially, the primary store (if set) is selected
    for (uint i = 0; i < model.get_n_items (); i++) {
      var persona_store = (PersonaStore) model.get_item (i);
      if (persona_store == contacts_store.aggregator.primary_store)
        this.selection.set_selected (i);
    }
  }

  private void on_model_items_changed (ListModel model, uint pos, uint removed, uint added) {
    for (uint i = pos; i < pos + removed; i++) {
      remove (this.rows[i]);
      this.rows.remove_index (i);
      // FIXME: ideally we'd just remove the rows at the given index here, but
      // AdwPreferencesGroup doesn't provide that API. As a workaround, we
      // "remove" them by making them invisible
    }

    for (uint i = pos; i < pos + added; i++) {
      var persona_store = (PersonaStore) model.get_item(i);
      var row = new AddressbookRow (persona_store);
      add (row);
      this.rows.add (row);

      // Update the selection model when the row is activated
      row.activated.connect (on_address_book_row_activated);
    }
  }

  private void on_address_book_row_activated (Adw.ActionRow row) {
    this.selection.set_selected ((uint) row.get_index ());
  }

  private class AddressbookRow : Adw.ActionRow {

    public PersonaStore persona_store { get; construct set; }

    public bool selected { get; set; default = false; }

    construct {
      var source = ((Edsf.PersonaStore) this.persona_store).source;
      var parent_source = eds_source_registry.ref_source (source.parent);

      debug ("Contact store \"%s\"",
             Utils.format_persona_store_name (this.persona_store));

      // Image
      var source_account_id = "";
      if (parent_source.has_extension (E.SOURCE_EXTENSION_GOA)) {
        var goa_source_ext = parent_source.get_extension (E.SOURCE_EXTENSION_GOA) as E.SourceGoa;
        source_account_id = goa_source_ext.account_id;
      }

      Gtk.Image? provider_image = null;
      if (this.persona_store.id != "system-address-book" && source_account_id != "")
        provider_image = Contacts.get_icon_for_goa_account (source_account_id);
      if (provider_image == null)
        provider_image = new Gtk.Image.from_icon_name (Config.APP_ID);
      provider_image.icon_size = Gtk.IconSize.LARGE;
      add_prefix (provider_image);

      // Title - subtitle
      this.title = Utils.format_persona_store_name (this.persona_store);
      if (parent_source.display_name != null) {
        this.subtitle = parent_source.display_name;
      } else if (source.has_extension (E.SOURCE_EXTENSION_WEBDAV_BACKEND)) {
        var webdav = (E.SourceWebdav)
            source.get_extension (E.SOURCE_EXTENSION_WEBDAV_BACKEND);
        if (webdav.email_address != null) {
          this.subtitle = webdav.email_address;
        } else {
          this.subtitle = webdav.uri.get_user ();
        }
      }

      // Checkmark
      var checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic");
      bind_property ("selected", checkmark, "visible", BindingFlags.SYNC_CREATE);
      add_suffix (checkmark);
      set_activatable_widget (checkmark);

      // Action menu
      var menu_button = new Gtk.MenuButton ();
      menu_button.icon_name = "view-more-symbolic";
      menu_button.add_css_class ("flat");
      add_suffix (menu_button);

      var menu = new GLib.Menu ();

      var main_section = new GLib.Menu ();
      if (parent_source.has_extension (E.SOURCE_EXTENSION_GOA)) {
        main_section.append (_("View in Online Accounts"), "app.launch-gnome-online-accounts");
      }
      menu.append_section (null, main_section);
      // Remove button (if applicable)
      if (source.removable) {
        var remove_section = new GLib.Menu ();
        remove_section.append (_("Remove address book"), "remove-address-book");
        // XXX
        // remove_button.clicked.connect ((b) => { remove_address_book (); });
        menu.append_section (null, remove_section);
      }
      menu_button.menu_model = menu;
    }

    public AddressbookRow (PersonaStore persona_store) {
      Object (persona_store: persona_store);
    }

    private void remove_address_book () {
      var dialog =
          new Adw.MessageDialog (get_root () as Gtk.Window,
                                 _("Are you sure you want to remove %s?").printf (this.title),
                                 _("If you remove this address book, it will no longer be accessible in any application"));
      dialog.add_response ("remove", _("_Remove"));
      dialog.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);

      dialog.add_response ("cancel", _("_Cancel"));
      dialog.set_default_response ("cancel");
      dialog.set_close_response ("cancel");
      dialog.response.connect ((response) => {
        if (response != "remove")
          return;

        //XXX
        var source = ((Edsf.PersonaStore) this.persona_store).source;
        var parent_source = eds_source_registry.ref_source (source.parent);

        debug ("Removing address book '%s'", this.title);
        source.remove.begin (null, (obj, res) => {
          try {
            source.remove.end (res);
            this.visible = false;
            debug ("Removed address book '%s'", this.title);
          } catch (Error e) {
            //XXX UI
            warning ("Couldn't remove address book: %s", e.message);
          }
        });
      });
      dialog.present ();
    }
  }
}
