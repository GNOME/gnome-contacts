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

const int PROFILE_SIZE = 128;

/**
 * The ContactPage is the right pane. It consists of 3 possible pages:
 * a page if nothing is selected, a ContactSheet to view contact information,
 * and a ContactEditor to edit contact information.
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-contact-pane.ui")]
public class Contacts.ContactPane : ScrolledWindow {

  private Window parent_window;

  private Store store;

  public Individual? individual { get; set; default = null; }

  [GtkChild]
  private Stack stack;

  [GtkChild]
  private Grid none_selected_page;

  [GtkChild]
  private Container contact_sheet_page;
  private ContactSheet? sheet = null;

  [GtkChild]
  private Box contact_editor_page;
  private ContactEditor? editor = null;

  public bool on_edit_mode = false;
  private LinkSuggestionGrid? suggestion_grid = null;

  /* Signals */
  public signal void contacts_linked (string? main_contact, string linked_contact, LinkOperation operation);
  /**
   * Passes the changed display name to all listeners after edit mode has been completed.
   */
  public signal void display_name_changed (string new_display_name);


  public ContactPane (Window parent_window, Store contacts_store) {
    this.parent_window = parent_window;
    this.store = contacts_store;
  }

  public void add_suggestion (Individual i) {
    var parent_overlay = this.get_parent () as Overlay;

    remove_suggestion_grid ();
    this.suggestion_grid = new LinkSuggestionGrid (i);
    parent_overlay.add_overlay (this.suggestion_grid);

    this.suggestion_grid.suggestion_accepted.connect ( () => {
        var linked_contact = this.individual.display_name;
        var operation = new LinkOperation (this.store);
        var to_link = new LinkedList<Individual> ();
        to_link.add (this.individual);
        to_link.add (i);
        operation.execute.begin (to_link);
        this.contacts_linked (null, linked_contact, operation);
        remove_suggestion_grid ();
      });

    this.suggestion_grid.suggestion_rejected.connect ( () => {
        /* TODO: Add undo */
        store.add_no_suggest_link (this.individual, i);
        remove_suggestion_grid ();
      });
  }

  public void show_contact (Individual? individual) {
    if (this.individual == individual)
      return;

    this.individual = individual;

    if (this.individual != null) {
      show_contact_sheet ();
    } else {
      remove_contact_sheet ();
      this.stack.set_visible_child (this.none_selected_page);
    }
  }

  private void show_contact_sheet () {
    assert (this.individual != null);

    remove_contact_sheet();
    this.sheet = new ContactSheet (this.individual, this.store);
    this.contact_sheet_page.add (this.sheet);
    this.stack.set_visible_child (this.contact_sheet_page);

    var matches = this.store.aggregator.get_potential_matches (this.individual, MatchResult.HIGH);
    foreach (var i in matches.keys) {
      if (i != null && Contacts.Utils.suggest_link_to (this.store, this.individual, i)) {
        add_suggestion (i);
        break;
      }
    }
  }

  private void remove_contact_sheet () {
    if (this.sheet == null)
      return;

    // Remove the suggestion grid that goes along with it.
    remove_suggestion_grid ();

    this.contact_sheet_page.remove (this.sheet);
    this.sheet.destroy();
    this.sheet = null;
  }

  private void create_contact_editor () {
    remove_contact_editor ();

    this.editor = new ContactEditor (this.individual, store.aggregator);

    this.contact_editor_page.add (this.editor);
  }

  private void remove_contact_editor () {
    if (this.editor == null)
      return;

    this.contact_editor_page.remove (this.editor);
    this.editor = null;
  }

  private void start_editing() {
    if (this.on_edit_mode || this.individual == null)
      return;

    this.on_edit_mode = true;

    create_contact_editor ();
    this.stack.set_visible_child (this.contact_editor_page);
  }

  public void stop_editing (bool cancel = false) {
    if (!this.on_edit_mode)
      return;

    this.on_edit_mode = false;
    remove_contact_editor ();

    if (cancel) {
      var fake_individual = individual as FakeIndividual;
      if (fake_individual != null && fake_individual.real_individual != null) {
        // Reset individual on to the real one
        this.individual = fake_individual.real_individual;
        this.stack.set_visible_child (this.contact_sheet_page);
      } else {
        this.stack.set_visible_child (this.none_selected_page);
      }
      return;
    }

    /* Save changes if editing wasn't canceled */
    apply_changes.begin ();
  }

  private async void apply_changes () {
    /* Show fake contact to the user */
    /* TODO: block changes to fake contact */
    show_contact_sheet ();
    var fake_individual = individual as FakeIndividual;
    if (fake_individual != null && fake_individual.real_individual == null) {
      // Create a new persona in the primary store based on the fake persona
      yield create_contact (fake_individual.primary_persona);
    } else {
      yield fake_individual.apply_changes_to_real ();
      /* Todo: we need to check if the changes where applied to the contact */
      this.individual = fake_individual.real_individual;
    }

    /* Replace fake contact with real contact */
    show_contact_sheet ();
  }

  public void edit_contact () {
    this.individual = new FakeIndividual.from_real (this.individual);
    start_editing ();
  }

  public void new_contact () {
    var details = new HashTable<string, Value?> (str_hash, str_equal);
    string[] writeable_properties;
    // TODO: make sure we have a primary_store
    if (this.store.aggregator.primary_store != null) {
      // FIXME: We shouldn't use this list but there isn't an other way to find writeable_properties, and we should expect that all properties are writeable
      writeable_properties = this.store.aggregator.primary_store.always_writeable_properties;
    } else {
      writeable_properties = {};
    }

    var fake_persona = new FakePersona (FakePersonaStore.the_store(), writeable_properties, details);
    var fake_personas = new HashSet<FakePersona> ();
    fake_personas.add (fake_persona);
    this.individual = new FakeIndividual(fake_personas);

    start_editing ();
  }

  // Create a new contact from the FakePersona
  public async void create_contact (FakePersona fake_persona) {
    var details = fake_persona.get_details ();

    if (this.store.aggregator.primary_store == null) {
      show_message_dialog (_("No primary addressbook configured"));
      return;
    }

    // Create the contact
    var primary_store = this.store.aggregator.primary_store;
    Persona? persona = null;
    try {
      persona = yield primary_store.add_persona_from_details (details);
    } catch (Error e) {
      show_message_dialog (_("Unable to create new contacts: %s").printf (e.message));
      this.parent_window.set_shown_contact (null);
      return;
    }

    // Now show the real persona to the user
    var individual = persona.individual;

    if (individual != null) {
      //FIXME: This causes a flicker, especially visibile when a avatar is set
      this.parent_window.set_shown_contact (individual);
    } else {
      show_message_dialog (_("Unable to find newly created contact"));
      this.parent_window.set_shown_contact (null);
    }
  }

  private void show_message_dialog (string message) {
    var dialog =
        new MessageDialog (this.parent_window,
                           DialogFlags.DESTROY_WITH_PARENT | DialogFlags.MODAL,
                           MessageType.ERROR,
                           ButtonsType.OK,
                           "%s", message);
    dialog.run ();
    dialog.destroy ();
  }

  private void remove_suggestion_grid () {
    if (this.suggestion_grid == null)
      return;

    this.suggestion_grid.destroy ();
    this.suggestion_grid = null;
  }
}
