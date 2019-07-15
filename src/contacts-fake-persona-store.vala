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

using Folks;
using Gee;

/**
 * A "dummy" store which is used to have an equivalent of a PersonaStore for a
 * FakePersona.
 */
public class Contacts.FakePersonaStore : PersonaStore {
  public static FakePersonaStore _the_store;
  public static FakePersonaStore the_store() {
    if (_the_store == null)
      _the_store = new FakePersonaStore ();
    return _the_store;
  }
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;

  public override string type_id { get { return "fake"; } }

  public FakePersonaStore () {
    Object (id: "uri", display_name: "fake store");
    this._personas = new HashMap<string, Persona> ();
    this._personas_ro = this._personas.read_only_view;
  }

  public override Map<string, Persona> personas {
      get { return this._personas_ro; }
  }

  public override MaybeBool can_add_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_alias_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_group_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_remove_personas { get { return MaybeBool.FALSE; } }
  public override bool is_prepared  { get { return true; } }
  public override bool is_quiescent  { get { return true; } }
  private string[] _always_writeable_properties = {};
  public override string[] always_writeable_properties { get { return this._always_writeable_properties; } }

  public override async void prepare () throws GLib.Error { }

  public override async Persona? add_persona_from_details (HashTable<string, Value?> details) throws Folks.PersonaStoreError {
    return null;
  }

  public override async void remove_persona (Persona persona) throws Folks.PersonaStoreError {
  }
}

/**
 * A "dummy" Persona which is used when creating a new contact
 * The FakePersona is used as a placeholder till we get the real persona from folks
 * It needs to implement all Details we support so that we don't loise any information
 */
public class Contacts.FakePersona : Persona,
  AvatarDetails,
  BirthdayDetails,
  EmailDetails,
  ImDetails,
  NameDetails,
  NoteDetails,
  PhoneDetails,
  UrlDetails,
  PostalAddressDetails
{
  private HashTable<string, Value?> properties;
  // Keep track of the persona in the actual store
  private weak Persona real_persona { get; set; default = null; }

  private const string[] _linkable_properties = {};
  private const string[] _writeable_properties = {};
  public override string[] linkable_properties {
    get { return _linkable_properties; }
  }

  public override string[] writeable_properties {
    get { return _writeable_properties; }
  }

  [CCode (notify = false)]
  public LoadableIcon? avatar
  {
    get { unowned Value? value = this.properties.get ("avatar");
      if (value == null)
        return null;
      return (LoadableIcon?) value;
    }
    set {}
  }

  [CCode (notify = false)]
  public string full_name
  {
    get { unowned Value? value = this.properties.get ("full-name");
      if (value == null)
        return "";
      return value.get_string (); }
    set {}
  }

  [CCode (notify = false)]
  public string nickname
  {
    get { unowned Value? value = this.properties.get ("nickname");
      if (value == null)
        return "";
      return value.get_string (); }
    set {}
  }

  [CCode (notify = false)]
  public StructuredName? structured_name
  {
    get { return null; }
    set {}
  }

  [CCode (notify = false)]
  public Set<PhoneFieldDetails> phone_numbers
  {
    get { unowned Value? value = this.properties.get ("phone-numbers");
      if (value == null) {
        var new_value = Value (typeof (Set));
        new_value.set_object (new HashSet<PhoneFieldDetails> ());
        this.properties.set ("phone-numbers", new_value);
        value = this.properties.get ("phone-numbers");
      }
      return (Set<PhoneFieldDetails>) value;
    }

    set {}
  }

  [CCode (notify = false)]
  public Set<UrlFieldDetails> urls
  {
    get { unowned Value? value = this.properties.get ("urls");
      if (value == null) {
        var new_value = Value (typeof (Set));
        new_value.set_object (new HashSet<UrlFieldDetails> ());
        this.properties.set ("urls", new_value);
        value = this.properties.get ("urls");
      }
      return (Set<UrlFieldDetails>) value;
    }

    set {}
  }

  [CCode (notify = false)]
  public Set<PostalAddressFieldDetails> postal_addresses
  {
    get { unowned Value? value = this.properties.get ("urls");
      if (value == null) {
        var new_value = Value (typeof (Set));
        new_value.set_object (new HashSet<PostalAddressFieldDetails> ());
        this.properties.set ("urls", new_value);
        value = new_value;
      }

      return (Set<PostalAddressFieldDetails>) value;
    }

    set {}
  }

  [CCode (notify = false)]
  public Set<NoteFieldDetails> notes
  {
    get { unowned Value? value = this.properties.get ("notes");
      if (value == null) {
        var new_value = Value (typeof (Set));
        new_value.set_object (new HashSet<NoteFieldDetails> ());
        this.properties.set ("notes", new_value);
        value = new_value;
      }
      return (Set<NoteFieldDetails>) value;
    }

    set {}
  }

  [CCode (notify = false)]
  public DateTime? birthday
  {
    get { unowned Value? value = this.properties.get ("birthday");
      if (value == null)
        return null;
      return (DateTime) value;
    }
    set {}
  }

  [CCode (notify = false)]
  public string? calendar_event_id
  {
    get { return null; }
    set {}
  }

  [CCode (notify = false)]
  public MultiMap<string,ImFieldDetails> im_addresses
  {
    get { unowned Value? value = this.properties.get ("im-addresses");
      if (value == null) {
        var new_value = Value (typeof (MultiMap));
        new_value.set_object (new HashMultiMap<string, ImFieldDetails> ());
        this.properties.set ("im-addresses", new_value);
        value = new_value;
      }

      return (MultiMap<string, ImFieldDetails>) value;
    }

    set {}
  }

  [CCode (notify = false)]
  public Set<EmailFieldDetails> email_addresses
  {
    get { unowned Value? value = this.properties.get ("email-addresses");
      if (value == null) {
        var new_value = Value (typeof (Set));
        new_value.set_object (new HashSet<EmailFieldDetails> ());
        this.properties.set ("email-addresses", new_value);
        value = new_value;
      }

      return (Set<EmailFieldDetails>) value;
    }
    set {}
  }

  public FakePersona (PersonaStore store, HashTable<string, Value?> details) {
    //TODO: use correct data to fill the object
    Object (display_id: "display-id-fake-persona",
            uid: "uid-fake-persona",
            iid: "iid",
            store: store,
            is_user: false);

    this.properties = details;
  }
}
