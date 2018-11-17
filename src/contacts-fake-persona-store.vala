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
 * A "dummy" Persona which is used when creating a new contact (to store
 * information).
 */
public class Contacts.FakePersona : Persona {
  public Contact contact;
  private class PropVal {
    public string property;
    public Value value;
  }
  private ArrayList<PropVal> prop_vals;
  private bool now_real;
  private bool has_full_name;

  public static FakePersona? maybe_create_for (Store store, Contact contact) {
    var primary_persona = contact.find_primary_persona ();

    if (primary_persona != null)
      return null;

    foreach (var p in contact.individual.personas) {
      // Don't fake a primary persona if we have an eds
      // persona on a non-readonly store
      if (p.store.type_id == "eds" &&
          p.store.can_add_personas == MaybeBool.TRUE &&
          p.store.can_remove_personas == MaybeBool.TRUE)
        return null;
    }

    return new FakePersona (store, contact);
  }

  private const string[] _linkable_properties = {};
  private const string[] _writeable_properties = {};
  public override string[] linkable_properties {
    get { return _linkable_properties; }
  }

  public override string[] writeable_properties {
    get { return _writeable_properties; }
  }

  public FakePersona (Store? store, Contact contact) {
    Object (display_id: "display_id",
            uid: "uid-fake-persona",
            iid: "iid",
            store: store.aggregator.primary_store ?? FakePersonaStore.the_store(),
            is_user: false);
    this.contact = contact;
    this.contact.fake_persona = this;
  }

  public async Persona? make_real_and_set (string property,
                                           Value value) throws IndividualAggregatorError, ContactError, PropertyError {
    var v = new PropVal ();
    v.property = property;
    v.value = value;
    if (property == "full-name")
      has_full_name = true;

    if (prop_vals == null) {
      prop_vals = new ArrayList<PropVal> ();
      prop_vals.add (v);
      Persona p = yield contact.ensure_primary_persona ();
      if (!has_full_name)
        p.set ("full-name", contact.individual.display_name);
      foreach (var pv in prop_vals) {
        yield Contact.set_persona_property (p, pv.property, pv.value);
      }
      now_real = true;
      return p;
    }

    assert (!now_real);
    prop_vals.add (v);
    return null;
  }
}
