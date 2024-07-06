/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 * Copyright (C) 2021 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

const int PROFILE_SIZE = 128;

/**
 * The ContactPage is the right pane. It consists of 3 possible pages:
 * a page if nothing is selected, a ContactSheet to view contact information,
 * and a ContactEditor to edit contact information.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-contact-pane.ui")]
public class Contacts.ContactPane : Adw.Bin {

  public unowned Store store { get; construct set; }

  public unowned ContactSelectionModel selection_model { get; construct set; }

  private Contact? contact = null;

  [GtkChild]
  private unowned Gtk.Stack stack;

  [GtkChild]
  private unowned Adw.Clamp contact_sheet_clamp;
  private unowned ContactSheet? sheet = null;

  [GtkChild]
  private unowned Gtk.Box contact_editor_box;
  private unowned ContactEditor? editor = null;

  public bool on_edit_mode = false;
  private LinkSuggestionGrid? suggestion_grid = null;

  public signal void contacts_linked (LinkOperation operation);

  public ContactPane (ContactSelectionModel selection_model, Store contacts_store) {
    Object (selection_model: selection_model, store: contacts_store);
  }

  public void add_suggestion (Individual individual, Individual other) {
    unowned var parent_toolbar = this.get_parent () as Adw.ToolbarView;

    remove_suggestion_grid ();
    this.suggestion_grid = new LinkSuggestionGrid (other);
    parent_toolbar.add_bottom_bar (this.suggestion_grid);

    this.suggestion_grid.suggestion_accepted.connect (() => {
      var to_link = new Gee.LinkedList<Individual> ();
      to_link.add (individual);
      to_link.add (other);
      var operation = new LinkOperation (this.store, to_link);
      this.contacts_linked (operation);
      remove_suggestion_grid ();
    });

    this.suggestion_grid.suggestion_rejected.connect (() => {
      /* TODO: Add undo */
      store.add_no_suggest_link (individual, other);
      remove_suggestion_grid ();
    });
  }

  public void show_contact (Individual? individual) {
    if (individual == null) {
      this.contact = null;
      remove_contact_sheet ();
      this.stack.set_visible_child_name ("none-selected-page");
      return;
    }

    if (this.contact == null || this.contact.individual != individual) {
      this.contact = new Contact.for_individual (individual);
    }
    show_contact_sheet (this.contact);
  }

  private void show_contact_sheet (Contact contact)
      requires (this.contact != null) {
    remove_contact_sheet ();
    var contacts_sheet = new ContactSheet (contact);
    contacts_sheet.hexpand = true;
    this.sheet = contacts_sheet;
    this.contact_sheet_clamp.set_child (this.sheet);
    this.stack.set_visible_child_name ("contact-sheet-page");

    // Show potential link suggestions only if it's an existing contact
    if (contact.individual != null) {
      var matches = this.store.aggregator.get_potential_matches (contact.individual, MatchResult.HIGH);
      foreach (var i in matches.keys) {
        if (i != null && this.store.suggest_link_to (contact.individual, i)) {
          add_suggestion (contact.individual, i);
          break;
        }
      }
    }
  }

  private void remove_contact_sheet () {
    if (this.sheet == null)
      return;

    // Remove the suggestion grid that goes along with it.
    remove_suggestion_grid ();

    this.contact_sheet_clamp.set_child (null);
    this.sheet = null;
  }

  private void create_contact_editor ()
      requires (this.contact != null) {

    remove_contact_editor ();
    var contact_editor = new ContactEditor (this.contact);
    contact_editor.hexpand = true;
    this.editor = contact_editor;

    this.contact_editor_box.append (this.editor);
  }

  private void remove_contact_editor () {
    if (this.editor == null)
      return;

    this.contact_editor_box.remove (this.editor);
    this.editor = null;
  }

  public void stop_editing (bool cancel = false)
      requires (this.on_edit_mode) {

    this.on_edit_mode = false;
    remove_contact_editor ();

    if (cancel) {
      if (this.contact != null) {
        this.stack.set_visible_child_name ("contact-sheet-page");
      } else {
        this.stack.set_visible_child_name ("none-selected-page");
      }
    } else {
      // Save changes if editing wasn't canceled
      apply_changes.begin (this.contact);
    }
  }

  private async void apply_changes (Contact contact) {
    // TODO: block changes to contact
    show_contact_sheet (contact);

    // Wait that the store gets quiescent if it isn't already
    if (!this.store.aggregator.is_quiescent) {
      ulong signal_id;
      SourceFunc callback = apply_changes.callback;
      signal_id = this.store.quiescent.connect (() => {
        callback ();
      });
      yield;
      disconnect (signal_id);
    }

    try {
      // The new individual. Even when editing an exisiting contact, it might
      // be a different Individual than before, so make sure to adjust our
      // selected contact afterwards
      var individual =
          yield contact.apply_changes (this.store.aggregator.primary_store);
      debug ("Applied changes resulted in individual (%s)",
             (individual != null)? individual.id : "null");

      if (individual != null) {
        var pos = yield this.store.find_individual_for_id (individual.id);
        if (pos != Gtk.INVALID_LIST_POSITION)
          this.selection_model.selected.selected = pos;
      }
    } catch (Error err) {
      warning ("Couldn't save changes: %s", err.message);
      show_contact (null);
      // XXX do something better here
    }
  }

  public void edit_contact ()
      requires (this.contact != null) {
    if (this.on_edit_mode)
      return;

    this.on_edit_mode = true;

    create_contact_editor ();
    this.stack.set_visible_child_name ("contact-editor-page");
  }

  public void new_contact () {
    this.contact = new Contact.empty ();
    if (this.on_edit_mode)
      return;

    this.on_edit_mode = true;

    create_contact_editor ();
    this.stack.set_visible_child_name ("contact-editor-page");
  }

  private void remove_suggestion_grid () {
    if (this.suggestion_grid == null)
      return;

    unowned var parent_toolbar = this.get_parent () as Adw.ToolbarView;
    parent_toolbar.remove (suggestion_grid);
    this.suggestion_grid = null;
  }
}
