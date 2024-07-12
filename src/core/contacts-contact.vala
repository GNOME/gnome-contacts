/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
    }
  }

  /** Creates a Contact that acts as a wrapper around an Individual */
  public Contact.for_individual (Individual individual) {
    Object (individual: individual);
  }

  /** Creates a Contact by deserializing the given GVariant */
  public Contact.for_gvariant (Variant variant)
      requires (variant.get_type ().equal (VariantType.VARDICT)) {
    Object (individual: null);

    var iter = variant.iterator ();
    string prop;
    Variant val;
    while (iter.next ("{sv}", out prop, out val)) {
      var pos = create_chunk_internal (prop, null);
      if (pos == -1)
        continue;

      unowned var chunk = this.chunks[pos];
      chunk.apply_gvariant (val, false);
    }
    items_changed (0, 0, this.chunks.length);
  }

  /** Creates a new empty contact */
  public Contact.empty () {
    Object (individual: null);

    // At the very least let's add an empty full-name chunk
    create_chunk ("full-name", null);
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
    if (pos == -1)
      return null;
    items_changed (pos, 0, 1);
    return this.chunks[pos];
  }

  // Helper to create a chunk and return its position, without items_changed()
  private int create_chunk_internal (string property_name, Persona? persona) {
    var chunk_gtype = chunk_gtype_for_property (property_name);
    if (chunk_gtype == GLib.Type.NONE) {
      debug ("unsupported property '%s', ignoring", property_name);
      return -1;
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
    unowned var alias_chunk = get_most_relevant_chunk ("alias");
    if (alias_chunk != null)
      return ((AliasChunk) alias_chunk).alias;

    unowned var fn_chunk = get_most_relevant_chunk ("full-name");
    if (fn_chunk != null)
      return ((FullNameChunk) fn_chunk).full_name;

    unowned var sn_chunk = get_most_relevant_chunk ("structured-name");
    if (sn_chunk != null)
      return ((StructuredNameChunk) sn_chunk).structured_name.to_string ();

    unowned var nick_chunk = get_most_relevant_chunk ("nickname");
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
  public unowned Chunk? get_most_relevant_chunk (string property_name,
                                                 bool allow_empty = false) {
    unowned Chunk? result = null;
    for (uint i = 0; i < this.chunks.length; i++) {
      unowned var chunk = this.chunks[i];

      // Filter out unwanted chunks
      if (chunk.property_name != property_name)
        continue;
      if (!allow_empty && chunk.is_empty)
        continue;

      // If we find a chunk from the primary persona, return immediately
      if (chunk.persona != null && chunk.persona.store.is_primary_store)
        return chunk;

      // Return the first occurrence later if we don't find a primary chunk
      if (result == null)
        result = chunk;
    }

    return result;
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
   * When a new persona is made, it will be added to @store.
   *
   * Returns the Individual that was created from applying the changes
   */
  public async Individual? apply_changes (PersonaStore store) throws GLib.Error {
    Individual? individual = null;

    // Create a (shallow) copy of the chunks
    var chunks = this.chunks.copy ((chunk) => { return chunk; });

    // For those that were a persona: save the properties using the API
    for (uint i = 0; i < chunks.length; i++) {
      unowned var chunk = chunks[i];
      if (chunk.persona == null)
        continue;

      if (individual == null)
        individual = chunk.persona.individual;

      if (!chunk.dirty) {
        debug ("Not saving unchanged property '%s' to persona %s",
               chunk.property_name, chunk.persona.uid);
        continue;
      }

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
    for (uint i = 0; i < chunks.length; i++) {
      unowned var chunk = chunks[i];
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
      var persona = yield store.add_persona_from_details (new_details);
      debug ("Successfully created new persona %p", persona);
      // FIXME: should we set the persona for these chunks?

      if (individual == null && persona != null)
        individual = persona.individual;
    }

    return individual;
  }

  /**
   * Serializes the given contact into a {@link GLib.Variant} (which can then
   * be transmitted over a socket). Note that this serialization format is only
   * intended for internal purposes and can change over time.
   *
   * For several reasons (for example easier deserialization and size decrease)
   * it will not serialize empty fields but omit them instead.
   */
  public Variant to_gvariant () {
    var dict = new GLib.VariantDict ();

    for (uint i = 0; i < this.chunks.length; i++) {
      unowned var chunk = this.chunks[i];

      var variant = chunk.to_gvariant ();
      if (variant == null)
        continue;

      dict.insert_value (chunk.property_name, variant);
    }

    return dict.end ();
  }
}
