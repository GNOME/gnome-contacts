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
  private Gee.HashMap<string, Persona> _personas;
  private Gee.Map<string, Persona> _personas_ro;

  public override string type_id { get { return "fake"; } }

  public FakePersonaStore () {
    Object (id: "uri", display_name: "fake store");
    this._personas = new Gee.HashMap<string, Persona> ();
    this._personas_ro = this._personas.read_only_view;
  }

  public override Gee.Map<string, Persona> personas {
    get { return this._personas_ro; }
  }

  public override MaybeBool can_add_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_alias_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_group_personas { get { return MaybeBool.FALSE; } }
  public override MaybeBool can_remove_personas { get { return MaybeBool.TRUE; } }
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
const string BACKEND_NAME = "fake-store";

public class Contacts.FakePersona : Persona,
                                    AvatarDetails,
                                    BirthdayDetails,
                                    EmailDetails,
                                    ImDetails,
                                    NameDetails,
                                    NoteDetails,
                                    PhoneDetails,
                                    UrlDetails,
                                    PostalAddressDetails {

  private HashTable<string, Value?> properties;
  // Keep track of the persona in the actual store
  public weak Persona real_persona { get; set; default = null; }

  private string[] _writeable_properties = {};
  private const string[] _linkable_properties = {};
  public override string[] linkable_properties {
    get { return _linkable_properties; }
  }

  public override string[] writeable_properties {
    get {
      return this._writeable_properties;
    }
  }

  private Gee.ArrayList<string> _changed_properties;

  construct {
    this._changed_properties = new Gee.ArrayList<string> ();
  }

  public LoadableIcon? avatar {
    get {
      unowned Value? value = this.properties.get ("avatar");
      // Casting a Value internally makes it use g_value_get_object(),
      // which is of course not allowed for a NULL value
      return (value != null)? (LoadableIcon?) value : null;
    }
    set {
      this.properties.set ("avatar", value);
    }
  }

  public async void change_avatar (LoadableIcon? avatar) throws PropertyError {
    this.avatar = avatar;
  }

  public string full_name {
    get {
      unowned Value? value = this.properties.get ("full-name");
      if (value == null)
        return "";
      return value.get_string ();
    }
    set {
      this.properties.set ("full-name", value);
    }
  }

  public string nickname {
    get {
      unowned Value? value = this.properties.get ("nickname");
      if (value == null)
        return "";
      return value.get_string ();
    }
    set {
      this.properties.set ("nickname", value);
    }
  }

  //TODO: implement structured_name
  public StructuredName? structured_name {
    get { return null; }
    set {}
  }

  public Gee.Set<PhoneFieldDetails> phone_numbers {
    get {
      unowned Value? value = this.properties.get ("phone-numbers");
      if (value == null) {
        var new_value = GLib.Value (typeof (Gee.Set));
        var set = new FakeHashSet<PhoneFieldDetails> ();
        new_value.set_object (set);
        set.changed.connect (() => { notify_property ("phone-numbers"); });
        this.properties.set ("phone-numbers", new_value);
        value = this.properties.get ("phone-numbers");
      }
      return (Gee.Set<PhoneFieldDetails>) value;
    }
    set {
      this.properties.set ("phone-numbers", value);
    }
  }

  public Gee.Set<UrlFieldDetails> urls {
    get {
      unowned Value? value = this.properties.get ("urls");
      if (value == null) {
        var new_value = Value (typeof (Gee.Set));
        var set = new FakeHashSet<UrlFieldDetails> ();
        new_value.set_object (set);
        set.changed.connect (() => { notify_property ("urls"); });
        this.properties.set ("urls", new_value);
        value = new_value;
      }
      return (Gee.Set<UrlFieldDetails>) value;
    }
    set {
      this.properties.set ("urls", value);
    }
  }

  public Gee.Set<PostalAddressFieldDetails> postal_addresses {
    get {
      unowned Value? value = this.properties.get ("postal-addresses");
      if (value == null) {
        var new_value = Value (typeof (Gee.Set));
        var set = new FakeHashSet<PostalAddressFieldDetails> ();
        new_value.set_object (set);
        set.changed.connect (() => { notify_property ("postal-addresses"); });
        this.properties.set ("postal-addresses", new_value);
        value = new_value;
      }
      return (Gee.Set<PostalAddressFieldDetails>) value;
    }
    set {
      this.properties.set ("postal-addresses", value);
    }
  }

  public Gee.Set<NoteFieldDetails> notes {
    get {
      unowned Value? value = this.properties.get ("notes");
      if (value == null) {
        var new_value = Value (typeof (Gee.Set));
        var set = new FakeHashSet<NoteFieldDetails> ();
        new_value.set_object (set);
        set.changed.connect (() => { notify_property ("notes"); });
        this.properties.set ("notes", new_value);
        value = new_value;
      }
      return (Gee.Set<NoteFieldDetails>) value;
    }
    set {
      this.properties.set ("notes", value);
    }
  }

  public DateTime? birthday {
    get { unowned Value? value = this.properties.get ("birthday");
      if (value == null)
        return null;
      return (DateTime) value;
    }
    set {
      this.properties.set ("birthday", value);
    }
  }

  //TODO implement calender_event_id
  public string? calendar_event_id {
    get { return null; }
    set {}
  }

  public Gee.MultiMap<string,ImFieldDetails> im_addresses {
    get {
      unowned Value? value = this.properties.get ("im-addresses");
      if (value == null) {
        var new_value = Value (typeof (Gee.MultiMap));
        var set = new FakeHashMultiMap<string, ImFieldDetails> ();
        new_value.set_object (set);
        this.properties.set ("im-addresses", new_value);
        set.changed.connect (() => { notify_property ("im-addresses"); });
        value = new_value;
      }
      return (Gee.MultiMap<string, ImFieldDetails>) value;
    }
    set {
      this.properties.set ("im-addresses", value);
    }
  }

  public Gee.Set<EmailFieldDetails> email_addresses {
    get {
      unowned Value? value = this.properties.get ("email-addresses");
      if (value == null) {
        var new_value = Value (typeof (Gee.Set));
        var set = new FakeHashSet<EmailFieldDetails> ();
        set.changed.connect (() => { notify_property ("email-addresses"); });
        new_value.set_object (set);
        this.properties.set ("email-addresses", new_value);
        value = new_value;
      }
      return (Gee.Set<EmailFieldDetails>) value;
    }
    set {
      this.properties.set ("email-addresses", value);
    }
  }

  public FakePersona (PersonaStore store, string[] writeable_properties, HashTable<string, Value?> details) {
    var id = Uuid.string_random();
    var uid = Folks.Persona.build_uid (BACKEND_NAME, store.id, id);
    var iid = "%s:%s".printf (store.id, id);
    Object (display_id: iid,
            uid: uid,
            iid: iid,
            store: store,
            is_user: false);

    this.properties = details;
    this._writeable_properties = writeable_properties;
  }

  public FakePersona.from_real (Persona persona) {
    var details = new HashTable<string, Value?> (str_hash, str_equal);
    this (FakePersonaStore.the_store (), persona.writeable_properties, details);
    // FIXME: get all properties not only writable properties
    var props = persona.writeable_properties;
    foreach (var prop in props) {
      get_property_from_real (persona, prop);
    }

    this.real_persona = persona;
    // FIXME: we are adding property changes also for things we don't care about e.g. individual
    this.notify.connect((obj, ps) => {
      add_to_changed_properties(ps.name);
    });
  }

  private void get_property_from_real (Persona persona, string property_name) {
    // TODO Implement the interface for the commented properties
    switch (property_name) {
      case "alias":
        //alias = ((AliasDetails) persona).alias;
        break;
      case "avatar":
        avatar = ((AvatarDetails) persona).avatar;
        break;
      case "birthday":
        birthday = ((BirthdayDetails) persona).birthday;
        break;
      case "calendar-event-id":
        calendar_event_id = ((BirthdayDetails) persona).calendar_event_id;
        break;
      case "email-addresses":
        foreach (var e in ((EmailDetails) persona).email_addresses) {
          email_addresses.add (new EmailFieldDetails (e.value, e.parameters));
        }
        break;
      case "is-favourite":
        //is_favourite = ((FavouriteDetails) persona).is_favourite;
        break;
      case "gender":
        //gender = ((GenderDetails) persona).gender;
        break;
      case "groups":
        //groups = ((GroupDetails) persona).groups;
        break;
      case "im-addresses":
        im_addresses = ((ImDetails) persona).im_addresses;
        break;
      case "local-ids":
        //local_ids = ((LocalIdDetails) persona).local_ids;
        break;
      case "structured-name":
        structured_name = ((NameDetails) persona).structured_name;
        break;
      case "full-name":
        full_name = ((NameDetails) persona).full_name;
        break;
      case "nickname":
        nickname = ((NameDetails) persona).nickname;
        break;
      case "notes":
        foreach (var e in ((NoteDetails) persona).notes) {
          notes.add (new NoteFieldDetails (e.value, e.parameters, e.id));
        }
        break;
      case "phone-numbers":
        foreach (var e in ((PhoneDetails) persona).phone_numbers) {
          phone_numbers.add (new PhoneFieldDetails (e.value, e.parameters));
        }
        break;
      case "postal-addresses":
        foreach (var e in ((PostalAddressDetails) persona).postal_addresses) {
          postal_addresses.add (new PostalAddressFieldDetails (e.value, e.parameters));
        }
        break;
      case "roles":
        //roles ((RoleDetails) persona).roles;
        break;
      case "urls":
        foreach (var e in ((UrlDetails) persona).urls) {
          urls.add (new UrlFieldDetails (e.value, e.parameters));
        }
        break;
      case "web-service-addresses":
        //web_service_addresses.add_all(((WebServiceDetails) persona).web_service_addresses);
        break;
      default:
        debug ("Unknown property '%s' in FakePersona.get_property_from_real().", property_name);
        break;
    }
  }

  private void add_to_changed_properties (string property_name) {
    debug ("Property: %s was added to the changed property list", property_name);
    if (!this._changed_properties.contains(property_name))
      this._changed_properties.add (property_name);
  }

  public HashTable<string, Value?>  get_details () {
    return this.properties;
  }

  public async void apply_changes_to_real () {
    if (this.real_persona == null) {
      warning ("No real persona to apply changes from fake persona");
      return;
    }
    foreach (var prop in _changed_properties) {
      if (properties.contains (prop)) {
        try {
        yield set_persona_property (this.real_persona, prop, properties.get (prop));
        } catch (Error e) {
          error ("Couldn't write property: %s", e.message);
        }
      }
    }
  }

  private static async void set_persona_property (Persona persona,
                                          string property_name, Value new_value) throws PropertyError, IndividualAggregatorError, PropertyError {
    switch (property_name) {
      case "alias":
        yield ((AliasDetails) persona).change_alias ((string) new_value);
        break;
      case "avatar":
        yield ((AvatarDetails) persona).change_avatar ((LoadableIcon?) new_value);
        break;
      case "birthday":
        yield ((BirthdayDetails) persona).change_birthday ((DateTime?) new_value);
        break;
      case "calendar-event-id":
        yield ((BirthdayDetails) persona).change_calendar_event_id ((string?) new_value);
        break;
      case "email-addresses":
        var original = (Gee.Set<EmailFieldDetails>) new_value;
        var copy = new Gee.HashSet<EmailFieldDetails> ();
        foreach (var e in original) {
          if (e.value != null && e.value != "")
            copy.add (new EmailFieldDetails (e.value, e.parameters));
        }
        yield ((EmailDetails) persona).change_email_addresses (copy);
        break;
      case "is-favourite":
        yield ((FavouriteDetails) persona).change_is_favourite ((bool) new_value);
        break;
      case "gender":
        yield ((GenderDetails) persona).change_gender ((Gender) new_value);
        break;
      case "groups":
        yield ((GroupDetails) persona).change_groups ((Gee.Set<string>) new_value);
        break;
      case "im-addresses":
        yield ((ImDetails) persona).change_im_addresses ((Gee.MultiMap<string, ImFieldDetails>) new_value);
        break;
      case "local-ids":
        yield ((LocalIdDetails) persona).change_local_ids ((Gee.Set<string>) new_value);
        break;
      case "structured-name":
        yield ((NameDetails) persona).change_structured_name ((StructuredName?) new_value);
        break;
      case "full-name":
        yield ((NameDetails) persona).change_full_name ((string) new_value);
        break;
      case "nickname":
        yield ((NameDetails) persona).change_nickname ((string) new_value);
        break;
      case "notes":
        var original = (Gee.Set<NoteFieldDetails>) new_value;
        var copy = new Gee.HashSet<NoteFieldDetails> ();
        foreach (var e in original) {
          if (e.value != null && e.value != "")
            copy.add (new NoteFieldDetails (e.value, e.parameters));
        }
        yield ((NoteDetails) persona).change_notes (copy);
        break;
      case "phone-numbers":
        var original = (Gee.Set<PhoneFieldDetails>) new_value;
        var copy = new Gee.HashSet<PhoneFieldDetails> ();
        foreach (var e in original) {
          if (e.value != null && e.value != "")
            copy.add (new PhoneFieldDetails (e.value, e.parameters));
        }
        yield ((PhoneDetails) persona).change_phone_numbers (copy);
        break;
      case "postal-addresses":
        var original = (Gee.Set<PostalAddressFieldDetails>) new_value;
        var copy = new Gee.HashSet<PostalAddressFieldDetails> ();
        foreach (var e in original) {
          if (e.value != null && !e.value.is_empty ())
            copy.add (new PostalAddressFieldDetails (e.value, e.parameters));
        }
        yield ((PostalAddressDetails) persona).change_postal_addresses (copy);
        break;
      case "roles":
        yield ((RoleDetails) persona).change_roles ((Gee.Set<RoleFieldDetails>) new_value);
        break;
      case "urls":
        var original = (Gee.Set<UrlFieldDetails>) new_value;
        var copy = new Gee.HashSet<UrlFieldDetails> ();
        foreach (var e in original) {
          if (e.value != null && e.value != "")
            copy.add (new UrlFieldDetails (e.value, e.parameters));
        }
        yield ((UrlDetails) persona).change_urls (copy);
        break;
      case "web-service-addresses":
        yield ((WebServiceDetails) persona).change_web_service_addresses ((Gee.MultiMap<string, WebServiceFieldDetails>) new_value);
        break;
      default:
        critical ("Unknown property '%s' in Contact.set_persona_property().", property_name);
        break;
    }
  }
}

/**
 * A FakeIndividual
 */
public class Contacts.FakeIndividual : Individual {
  public weak Individual real_individual { get; set; default = null; }
  public weak FakePersona primary_persona { get; set; default = null; }
  public FakeIndividual (Gee.Set<FakePersona>? personas) {
    base (personas);
    foreach (var p in personas) {
      // Keep track of the main persona
      if (Contacts.Utils.persona_is_main (p) || personas.size == 1)
        primary_persona = p;
    }
  }

  public FakeIndividual.from_real (Individual individual) {
    var fake_personas = new Gee.HashSet<FakePersona> ();
    foreach (var p in individual.personas) {
      var fake_p = new FakePersona.from_real (p);
      // Keep track of the main persona
      if (Contacts.Utils.persona_is_main (p) || individual.personas.size == 1)
        primary_persona = fake_p;
      fake_personas.add (fake_p);
    }
    this (fake_personas);
    this.real_individual = individual;
  }

  public async void apply_changes_to_real () {
    if (this.real_individual == null) {
      warning ("No real individual to apply changes from fake individual");
      return;
    }

    foreach (var p in this.personas) {
        var fake_persona = p as FakePersona;
        if (fake_persona != null) {
          yield fake_persona.apply_changes_to_real ();
        }
      }
  }
}

/**
 * This is the same as Gee.HashSet but adds a changed/added/removed signals
 */
public class Contacts.FakeHashSet<T> : Gee.HashSet<T> {
  public signal void changed ();
  public signal void added ();
  public signal void removed ();

  public FakeHashSet () {
    base ();
  }

  public override bool add (T element) {
    var res = base.add (element);
    if (res) {
      added();
      changed ();
    }
    return res;
  }

  public override bool remove (T element) {
    var res = base.remove (element);
    if (res) {
      removed();
      changed ();
    }
    return res;
  }
}

/**
 * This is the same as Gee.HashMultiMap but adds a changed signal
 */
public class Contacts.FakeHashMultiMap<K, T> : Gee.HashMultiMap<K, T> {
  public signal void changed ();

  public FakeHashMultiMap () {
    base ();
  }
}
