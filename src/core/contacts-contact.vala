/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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

/**
 * A Contact is an object that represents a data model around a set of
 * contact properties. This can either come from a {@link Folks.Individual}, an
 * empty set (when creating contacts) or a different data source (like a vCard).
 *
 * Since the classes Folks provides assume valid data, we can't/shouldn't
 * really use them (for example, a PostalAddresFieldDetails does not allow
 * empty addresses), so that is another easy use for this separate class.
 */
public class Contacts.Contact : GLib.Object, GLib.ListModel {

  private GenericArray<Chunk> chunks = new GenericArray<Chunk> ();

  /** The underlying individual, if any */
  public unowned Individual? individual { get; construct set; default = null; }

  public unowned Store contacts_store { get; construct set; }

  /** Similar to fetch_display_name(), but never returns null */
  public string display_name {
    owned get { return fetch_display_name () ?? _("Unnamed Person"); }
  }

  construct {
    if (this.individual != null) {
      this.individual.personas_changed.connect (on_individual_personas_changed);
      on_individual_personas_changed (this.individual,
                                      this.individual.personas,
                                      Gee.Set.empty<Persona> ());
    } else {
      // At the very least let's add an empty full-name chunk
      create_chunk ("full-name", null);
    }
  }

  /** Creates a Contact that acts as a wrapper around an Individual */
  public Contact.for_individual (Individual individual, Store contacts_store) {
    Object (individual: individual, contacts_store: contacts_store);
  }

  /** Creates a new empty contact */
  public Contact.for_new (Store contacts_store) {
    Object (individual: null, contacts_store: contacts_store);
  }

  private void on_individual_personas_changed (Individual individual,
                                               Gee.Set<Persona> added,
                                               Gee.Set<Persona> removed) {
    uint old_size = this.chunks.length;
    foreach (var persona in added)
      add_persona (persona);
    items_changed (old_size - 1, 0, this.chunks.length - old_size);

    foreach (var persona in removed) {
      for (uint i = 0; i < this.chunks.length; i++) {
        if (this.chunks[i].persona == persona) {
          this.chunks.remove_index (i);
          items_changed (i, 1, 0);
          i--;
        }
      }
    }
  }

  private void add_persona (Persona persona) {
    if (persona is AliasDetails)
      create_chunk_internal ("alias", persona);
    if (persona is AvatarDetails)
      create_chunk_internal ("avatar", persona);
    if (persona is BirthdayDetails)
      create_chunk_internal ("birthday", persona);
    if (persona is EmailDetails)
      create_chunk_internal ("email-addresses", persona);
    if (persona is ImDetails)
      create_chunk_internal ("im-addresses", persona);
    if (persona is NameDetails) {
      create_chunk_internal ("full-name", persona);
      create_chunk_internal ("structured-name", persona);
      create_chunk_internal ("nickname", persona);
    }
    if (persona is NoteDetails)
      create_chunk_internal ("notes", persona);
    if (persona is PhoneDetails)
      create_chunk_internal ("phone-numbers", persona);
    if (persona is PostalAddressDetails)
      create_chunk_internal ("postal-addresses", persona);
    if (persona is RoleDetails)
      create_chunk_internal ("roles", persona);
    if (persona is UrlDetails)
      create_chunk_internal ("urls", persona);
  }

  public unowned Chunk? create_chunk (string property_name, Persona? persona) {
    var pos = create_chunk_internal (property_name, persona);
    if (pos == Gtk.INVALID_LIST_POSITION)
      return null;
    items_changed (pos, 0, 1);
    return this.chunks[pos];
  }

  // Helper to create a chunk and return its position, without items_changed()
  private uint create_chunk_internal (string property_name, Persona? persona) {
    var chunk_gtype = chunk_gtype_for_property (property_name);
    if (chunk_gtype == GLib.Type.NONE) {
      debug ("unsupported property '%s', ignoring", property_name);
      return Gtk.INVALID_LIST_POSITION;
    }

    var chunk = (Chunk) Object.new (chunk_gtype,
                                    "persona", persona,
                                    null);
    this.chunks.add (chunk);
    return this.chunks.length - 1;
  }

  private GLib.Type chunk_gtype_for_property (string property_name) {
    switch (property_name) { // Please keep these sorted
      case "alias":
        return typeof (AliasChunk);
      case "avatar":
        return typeof (AvatarChunk);
      case "birthday":
        return typeof (BirthdayChunk);
      case "email-addresses":
        return typeof (EmailAddressesChunk);
      case "full-name":
        return typeof (FullNameChunk);
      case "im-addresses":
        return typeof (ImAddressesChunk);
      case "nickname":
        return typeof (NicknameChunk);
      case "notes":
        return typeof (NotesChunk);
      case "phone-numbers":
        return typeof (PhonesChunk);
      case "postal-addresses":
        return typeof (AddressesChunk);
      case "roles":
        return typeof (RolesChunk);
      case "structured-name":
        return typeof (StructuredNameChunk);
      case "urls":
        return typeof (UrlsChunk);
    }

    return GLib.Type.NONE;
  }

  /**
   * Tries to get the name for the contact by iterating over the chunks that
   * represent some form of name. If none is found, it returns null.
   */
  public string? fetch_name () {
    var alias_chunk = get_most_relevant_chunk ("alias");
    if (alias_chunk != null)
      return ((AliasChunk) alias_chunk).alias;

    var fn_chunk = get_most_relevant_chunk ("full-name");
    if (fn_chunk != null)
      return ((FullNameChunk) fn_chunk).full_name;

    var sn_chunk = get_most_relevant_chunk ("structured-name");
    if (sn_chunk != null)
      return ((StructuredNameChunk) sn_chunk).structured_name.to_string ();

    var nick_chunk = get_most_relevant_chunk ("nickname");
    if (nick_chunk != null)
      return ((NicknameChunk) nick_chunk).nickname;

    return null;
  }

  /**
   * Tries to get the displayable name for the contact. Similar to fetch_name,
   * but also checks for fields that are not a name, but might still represent
   * a contact (for example an email address)
   */
  public string? fetch_display_name () {
    var name = fetch_name ();
    if (name != null)
      return name;

    var emails_chunk = get_most_relevant_chunk ("email-addresses");
    if (emails_chunk != null) {
      var email = ((EmailAddressesChunk) emails_chunk).get_item (0);
      return ((EmailAddress) email).raw_address;
    }

    var phones_chunk = get_most_relevant_chunk ("phone-numbers");
    if (phones_chunk != null) {
      var phone = ((PhonesChunk) phones_chunk).get_item (0);
      return ((Phone) phone).raw_number;
    }

    return null;
  }

  /**
   * A helper function to return the {@link Chunk} that best represents the
   * property of the contact (or null if none).
   */
  public Chunk? get_most_relevant_chunk (string property_name, bool allow_empty = false) {
    var filter = new ChunkFilter.for_property (property_name);
    filter.allow_empty = allow_empty;
    var chunks = new Gtk.FilterListModel (this, (owned) filter);

    // From these chunks, select the one from the primary store. If there's
    // none, just select the first one
    unowned var primary_store = this.contacts_store.aggregator.primary_store;
    for (uint i = 0; i < chunks.get_n_items (); i++) {
      var chunk = (Chunk) chunks.get_item (i);
      if (chunk.persona != null && chunk.persona.store == primary_store)
        return chunk;
    }
    return (Chunk?) chunks.get_item (0);
  }

  public Object? get_item (uint i) {
    if (i > this.chunks.length)
      return null;
    return this.chunks[i];
  }

  public uint get_n_items () {
    return this.chunks.length;
  }

  public GLib.Type get_item_type () {
    return typeof (Chunk);
  }

  /**
   * Applies any pending changes to all chunks. This can mean either a new
   * persona is made, or it is saved in the chunk's referenced persona.
   */
  public async void apply_changes () throws GLib.Error {
    // For those that were a persona: save the properties using the API
    for (uint i = 0; i < this.chunks.length; i++) {
      unowned var chunk = this.chunks[i];
      if (chunk.persona == null)
        continue;

      if (!(chunk.property_name in chunk.persona.writeable_properties)) {
        warning ("Can't save to unwriteable property '%s' to persona %s",
                 chunk.property_name, chunk.persona.uid);
        // TODO: maybe add a fallback to save to a different persona?
        // We could maybe store it and add it to a new one, but that might make
        // properties overlap
        continue;
      }

      debug ("Saving property '%s' to persona %s",
             chunk.property_name, chunk.persona.uid);
      yield chunk.save_to_persona ();
      debug ("Saved property '%s' to persona %s",
             chunk.property_name, chunk.persona.uid);
    }

    // Find those without a persona, and save them into the primary store
    var new_details = new HashTable<string, Value?> (str_hash, str_equal);
    for (uint i = 0; i < this.chunks.length; i++) {
      unowned var chunk = this.chunks[i];
      if (chunk.persona != null)
        continue;

      var value = chunk.to_value ();
      if (value == null // Skip empty properties
          || value.peek_pointer () == null) // ugh, Vala
        continue;

      if (chunk.property_name in new_details)
        warning ("Got multiple chunks for property '%s'", chunk.property_name);
      new_details.insert (chunk.property_name, (owned) value);
    }
    if (new_details.size () != 0) {
      debug ("Creating new persona with %u properties", new_details.size ());
      unowned var primary_store = this.contacts_store.aggregator.primary_store;
      return_if_fail (primary_store != null);
      var persona = yield primary_store.add_persona_from_details (new_details);
      debug ("Successfully created new persona %p", persona);
      // FIXME: should we set the persona for these chunks?
    }
  }
}