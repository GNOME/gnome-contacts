/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
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

namespace Contacts {
  public class LinkOperation : Object {
    internal class Change {
      public PersonaAttribute attribute;
      public Persona persona;
      public Object old_value;
    }
    private Persona? _added_persona;
    private Individual? main_contact;
    private ArrayList<Persona>? split_out_personas;
    ArrayList<Change> changes;

    public LinkOperation() {
      changes = new ArrayList<Change> ();
    }

    public void set_main_contact (Individual? individual) {
      main_contact = individual;
    }

    public void set_split_out_contact (Individual? individual) {
      if (individual != null) {
	split_out_personas = new ArrayList<Persona> ();
	split_out_personas.add_all (individual.personas);
      }
    }

    public void added_persona (Persona persona) {
      _added_persona = persona;
    }

    public void add_change (PersonaAttribute attribute, Persona persona, Object old_value) {
      var c = new Change ();
      c.attribute = attribute;
      c.persona = persona;
      c.old_value = old_value;
      changes.add (c);
    }

    public async void undo () {
      if (main_contact != null)
	main_contact.set_data ("contacts-master-at-join", true);
      if (split_out_personas != null) {
	foreach (var p in split_out_personas)
	  p.set_data ("contacts-new-contact", true);
      }

      try {
	if (_added_persona != null) {
	  yield _added_persona.store.remove_persona (_added_persona);
	}
	foreach (var c in changes) {
	  if (c.persona != _added_persona) {
	    yield c.attribute.set_value (c.persona, c.old_value);
	  }
	}
      } catch (GLib.Error e) {
	warning ("Error when undoing linking: %s\n", e.message);
      }

      if (main_contact != null)
	main_contact.set_data ("contacts-master-at-join", false);

      if (split_out_personas != null) {
	foreach (var p in split_out_personas)
	  p.set_data ("contacts-new-contact", false);
      }
    }
  }

  public abstract class PersonaAttribute : Object {
    public string property_name;

    public static HashSet<PersonaAttribute> create_set () {
      return new HashSet<PersonaAttribute>((HashDataFunc<PersonaAttribute>) PersonaAttribute.hash,
					   (EqualDataFunc<PersonaAttribute>) PersonaAttribute.equal);
    }

    public virtual bool is_removable (Persona from_persona) {
      return (property_name in from_persona.writeable_properties);
    }

    public abstract bool is_referenced_by_persona (Persona persona);

    public abstract string to_string ();

    public virtual bool equal (PersonaAttribute that) {
      return this.property_name == that.property_name;
    }

    public virtual uint hash () {
      return this.property_name.hash ();
    }

    public abstract async void persona_apply_attributes (Persona persona,
							 Set<PersonaAttribute> added_attributes,
							 Set<PersonaAttribute> removed_attributes,
							 LinkOperation operation);
    public abstract async void set_value (Persona persona, Object value);
  }

  internal class PersonaAttributeLocalId : PersonaAttribute {
    string value;

    public PersonaAttributeLocalId (string value) {
      property_name = "local-ids";
      this.value = value;
    }

    public override bool is_removable (Persona from_persona) {
      return base.is_removable (from_persona) && value != from_persona.iid;
    }

    public override string to_string () {
      return "local_id: " + value;
    }

    public override bool is_referenced_by_persona (Persona persona) {
      var details = persona as LocalIdDetails;
      if (details == null)
	return false;

      return value in details.local_ids;
    }

    public override async void persona_apply_attributes (Persona persona,
							 Set<PersonaAttribute> added_attributes,
							 Set<PersonaAttribute> removed_attributes,
							 LinkOperation operation) {
      var details = persona as LocalIdDetails;
      if (details == null)
	return;

      var added_values = new HashSet<string> ();
      foreach (var added in added_attributes) {
	added_values.add (((PersonaAttributeLocalId)added).value);
      }

      var removed_values = new HashSet<string> ();
      foreach (var removed in removed_attributes) {
	removed_values.add (((PersonaAttributeLocalId)removed).value);
      }

      var new_values = new HashSet<string> ();
      bool changed = false;
      foreach (var v in details.local_ids) {
	if (v in removed_values) {
	  changed = true;
	  continue;
	}
	new_values.add (v);
	if (v in added_values)
	  added_values.remove (v);
      }
      foreach (var v2 in added_values) {
	changed = true;
	new_values.add (v2);
      }

      if (changed) {
	try {
	  var old_value = new HashSet<string> ();
	  old_value.add_all (details.local_ids);
	  yield details.change_local_ids (new_values);
	  operation.add_change (this, persona, old_value);
	} catch (GLib.Error e) {
	  warning ("Unable to set local ids when linking: %s\n", e.message);
	}
      }
    }

    public override async void set_value (Persona persona, Object value) {
      var details = persona as LocalIdDetails;
      if (details == null)
	return;

      try {
	var v = value as HashSet<string>;
	yield details.change_local_ids (v);
      } catch (GLib.Error e) {
	warning ("Unable to set local ids when undoing link: %s\n", e.message);
      }
    }

    public override bool equal (PersonaAttribute _that) {
      var that = _that as PersonaAttributeLocalId;
      return
	that != null &&
	base.equal (that) &&
	this.value == that.value;
    }

    public override uint hash () {
      return this.value.hash () ^ base.hash ();
    }
  }

  internal class PersonaAttributeImAddress : PersonaAttribute {
    string protocol;
    ImFieldDetails detail;

    public PersonaAttributeImAddress (string protocol, ImFieldDetails detail) {
      property_name = "im-addresses";
      this.protocol = protocol;
      this.detail = detail;
    }

    public override string to_string () {
      return "im_addresses: " + protocol + ":" + detail.value;
    }

    public override bool is_referenced_by_persona (Persona persona) {
      var details = persona as ImDetails;
      if (details == null)
	return false;

      return detail in details.im_addresses.get (protocol);
    }

    public override async void persona_apply_attributes (Persona persona,
							 Set<PersonaAttribute> added_attributes,
							 Set<PersonaAttribute> removed_attributes,
							 LinkOperation operation) {
      var details = persona as ImDetails;
      if (details == null)
	return;

      var added_values = new HashMultiMap<string, ImFieldDetails> (null, null,
								   AbstractFieldDetails<string>.hash_static,
								   AbstractFieldDetails<string>.equal_static);
      foreach (var added in added_attributes) {
	added_values.set (((PersonaAttributeImAddress)added).protocol, ((PersonaAttributeImAddress)added).detail);
      }

      var removed_values = new HashMultiMap<string, ImFieldDetails> (null, null,
								     AbstractFieldDetails<string>.hash_static,
								     AbstractFieldDetails<string>.equal_static);

      foreach (var removed in removed_attributes) {
	removed_values.set (((PersonaAttributeImAddress)removed).protocol, ((PersonaAttributeImAddress)removed).detail);
      }

      var new_values =
	new HashMultiMap<string, ImFieldDetails> (null, null,
						  AbstractFieldDetails<string>.hash_static,
						  AbstractFieldDetails<string>.equal_static);
      bool changed = false;
      foreach (var proto1 in details.im_addresses.get_keys ()) {
	foreach (var detail1 in details.im_addresses.get (proto1)) {
	  if (removed_values.get (proto1).contains (detail1)) {
	    changed = true;
	    continue;
	  }
	  new_values.set (proto1, detail1);
	  if (added_values.get (proto1).contains (detail1)) {
	    added_values.remove (proto1, detail1);
	  }
	}
      }
      foreach (var proto2 in added_values.get_keys ()) {
	foreach (var detail2 in added_values.get (proto2)) {
	  changed = true;
	  new_values.set (proto2, detail2);
	}
      }

      if (changed) {
	try {
	  var old_value = details.im_addresses;
	  yield details.change_im_addresses (new_values);
	  operation.add_change (this, persona, old_value);
	} catch (GLib.Error e) {
	  warning ("Unable to set im address when linking: %s\n", e.message);
	}
      }
    }

    public override async void set_value (Persona persona, Object value) {
      var details = persona as ImDetails;
      if (details == null)
	return;

      try {
	var v = value as HashMultiMap<string, ImFieldDetails>;
	yield details.change_im_addresses (v);
      } catch (GLib.Error e) {
	warning ("Unable to set local ids when undoing link: %s\n", e.message);
      }
    }

    public override bool equal (PersonaAttribute _that) {
      var that = _that as PersonaAttributeImAddress;
      return
	that != null &&
	base.equal (that) &&
	this.protocol == that.protocol &&
	this.detail.equal (that.detail);
    }

    public override uint hash () {
      return this.protocol.hash () ^ this.detail.hash () ^ base.hash ();
    }
  }

  internal class PersonaAttributeWebService : PersonaAttribute {
    string service;
    WebServiceFieldDetails detail;

    public PersonaAttributeWebService (string service, WebServiceFieldDetails detail) {
      property_name = "web-service-addresses";
      this.service = service;
      this.detail = detail;
    }

    public override string to_string () {
      return "web_service_addresses: " + service + ":" + detail.value;
    }

    public override bool is_referenced_by_persona (Persona persona) {
      var details = persona as WebServiceDetails;
      if (details == null)
	return false;

      return detail in details.web_service_addresses.get (service);
    }

    public override async void persona_apply_attributes (Persona persona,
							 Set<PersonaAttribute> added_attributes,
							 Set<PersonaAttribute> removed_attributes,
							 LinkOperation operation) {
      var details = persona as WebServiceDetails;
      if (details == null)
	return;

      var added_values = new HashMultiMap<string, WebServiceFieldDetails> (null, null,
									   AbstractFieldDetails<string>.hash_static,
									   AbstractFieldDetails<string>.equal_static);
      foreach (var added in added_attributes) {
	added_values.set (((PersonaAttributeWebService)added).service, ((PersonaAttributeWebService)added).detail);
      }

      var removed_values = new HashMultiMap<string, WebServiceFieldDetails> (null, null,
									     AbstractFieldDetails<string>.hash_static,
									     AbstractFieldDetails<string>.equal_static);
      foreach (var removed in removed_attributes) {
	removed_values.set (((PersonaAttributeWebService)removed).service, ((PersonaAttributeWebService)removed).detail);
      }

      var new_values =
	new HashMultiMap<string, WebServiceFieldDetails> (null, null,
							  AbstractFieldDetails<string>.hash_static,
							  AbstractFieldDetails<string>.equal_static);
      bool changed = false;
      foreach (var srv1 in details.web_service_addresses.get_keys ()) {
	foreach (var detail1 in details.web_service_addresses.get (srv1)) {
	  if (removed_values.get (srv1).contains (detail1)) {
	    changed = true;
	    continue;
	  }
	  new_values.set (srv1, detail1);
	  if (added_values.get (srv1).contains (detail1)) {
	    added_values.remove (srv1, detail1);
	  }
	}
      }
      foreach (var srv2 in added_values.get_keys ()) {
	foreach (var detail2 in added_values.get (srv2)) {
	  changed = true;
	  new_values.set (srv2, detail2);
	}
      }

      if (changed) {
	try {
	  var old_value = details.web_service_addresses;
	  yield details.change_web_service_addresses (new_values);
	  operation.add_change (this, persona, old_value);
	} catch (GLib.Error e) {
	  warning ("Unable to set web service when linking: %s\n", e.message);
	}
      }
    }

    public override async void set_value (Persona persona, Object value) {
      var details = persona as WebServiceDetails;
      if (details == null)
	return;

      try {
	var v = value as HashMultiMap<string, WebServiceFieldDetails>;
	yield details.change_web_service_addresses (v);
      } catch (GLib.Error e) {
	warning ("Unable to set local ids when undoing link: %s\n", e.message);
      }
    }

    public override bool equal (PersonaAttribute _that) {
      var that = _that as PersonaAttributeWebService;
      return
	that != null &&
	base.equal (that) &&
	this.service == that.service &&
	this.detail.equal (that.detail);
    }

    public override uint hash () {
      return this.service.hash () ^ this.detail.hash () ^ base.hash ();
    }
  }

  public static void add_linkable_attributes (HashSet<PersonaAttribute> set, Persona persona) {
    if (persona is LocalIdDetails) {
      foreach (var id in ((LocalIdDetails) persona).local_ids) {
	set.add (new PersonaAttributeLocalId (id));
      }
    }

    if (persona is ImDetails) {
      foreach (var proto in ((ImDetails) persona).im_addresses.get_keys ()) {
	foreach (var im in ((ImDetails) persona).im_addresses.get (proto)) {
	  set.add (new PersonaAttributeImAddress (proto, im));
	}
      }
    }

    if (persona is WebServiceDetails) {
      foreach (var srv in ((WebServiceDetails) persona).web_service_addresses.get_keys ()) {
	foreach (var web in ((WebServiceDetails) persona).web_service_addresses.get (srv)) {
	  set.add (new PersonaAttributeWebService (srv, web));
	}
      }
    }
  }

  public static Set<PersonaAttribute> get_linkable_attributes (Persona persona) {
    var res = PersonaAttribute.create_set ();
    add_linkable_attributes (res, persona);
    return res;
  }

  public static Set<PersonaAttribute> get_linkable_attributes_for_individual (Individual individual) {
    var res = PersonaAttribute.create_set ();
    foreach (var persona in individual.personas)
      add_linkable_attributes (res, persona);
    return res;
  }

  public static bool persona_can_link_to (Persona persona, Set<PersonaAttribute> attributes) {
    var property_names = new HashSet<string>();
    foreach (var a in attributes)
      property_names.add (a.property_name);

    foreach (var p in property_names) {
      if (! (p in persona.writeable_properties))
	return false;
    }
    return true;
  }

  internal bool attr_type_equal (PersonaAttribute a, PersonaAttribute b) {
    return
      a.get_type() == b.get_type() &&
      a.property_name == b.property_name;
  }

  public static async void persona_apply_attributes (Persona persona,
						     Set<PersonaAttribute>? added_attributes,
						     Set<PersonaAttribute>? removed_attributes,
						     LinkOperation operation) {
    var properties = new HashSet<PersonaAttribute>();

    if (added_attributes != null) {
      foreach (var a1 in added_attributes) {
	properties.add (a1);
      }
    }
    if (removed_attributes != null) {
      foreach (var a2 in removed_attributes) {
	properties.add (a2);
      }
    }

    foreach (var property in properties) {
      var added = PersonaAttribute.create_set ();
      var removed = PersonaAttribute.create_set ();
      if (added_attributes != null) {
	foreach (var a3 in added_attributes) {
	  if (attr_type_equal (a3, property))
	    added.add (a3);
	}
      }
      if (removed_attributes != null) {
	foreach (var a4 in removed_attributes) {
	  if (attr_type_equal (a4, property))
	    removed.add (a4);
	}
      }
      yield property.persona_apply_attributes (persona, added, removed, operation);
    }
  }

  public async LinkOperation link_contacts (Individual main, Individual? other, Store contacts_store) {
    // This should not be used as being replaced with the new individual
    // instead we should always pick this contact to keep around
    main.set_data ("contacts-master-at-join", true);

    var operation = new LinkOperation ();
    operation.set_split_out_contact (other);

    var main_linkables = get_linkable_attributes_for_individual (main);
    Set<PersonaAttribute>? other_linkables = null;
    if (other != null)
      other_linkables = get_linkable_attributes_for_individual (other);
    Set<PersonaAttribute>? linkables = null;

    // Remove all linkable data from each contact that is already in the other contact
    if (other_linkables != null) {
      main_linkables.remove_all (other_linkables);
      other_linkables.remove_all (main_linkables);
    }

    Persona? write_persona = null;
    foreach (var p1 in main.personas) {
      if (other_linkables != null &&
	  persona_can_link_to (p1, other_linkables)) {
	write_persona = p1;
	linkables = other_linkables;
	if (write_persona.store.is_primary_store)
	  break; // Exit if we find a primary persona, as we prefer these
      }
    }

    if (other != null &&
	(write_persona == null || !write_persona.store.is_primary_store)) {
      foreach (var p2 in other.personas) {
	if (persona_can_link_to (p2, main_linkables)) {
	  // Only override main persona if its a primary store persona
	  if (write_persona == null || p2.store.is_primary_store) {
	    write_persona = p2;
	    linkables = main_linkables;
	    if (write_persona.store.is_primary_store)
	      break; // Exit if we find a primary persona, as we prefer these
	  }
	}
      }
    }

    if (write_persona == null) {
      var details = new HashTable<string, Value?> (str_hash, str_equal);
      try {
	var v = Value (typeof (string));
	v.set_string (main.display_name);
	details.set ("full-name", v);
	write_persona = yield contacts_store.aggregator.primary_store.add_persona_from_details (details);
	operation.added_persona (write_persona);
	linkables = main_linkables;
	if (other_linkables != null)
	  linkables.add_all (other_linkables);
      } catch (GLib.Error e) {
	main.set_data ("contacts-master-at-join", false);
	warning ("Unable to create new persona when linking: %s\n", e.message);
	return operation;
      }
    }

    yield persona_apply_attributes (write_persona, linkables, null, operation);

    main.set_data ("contacts-master-at-join", false);

    return operation;
  }

  public async LinkOperation unlink_persona (Store store, Individual individual, Persona persona_to_unlink) {
    var persona_to_unlink_removals = PersonaAttribute.create_set ();
    var other_personas_removals = PersonaAttribute.create_set ();

    var operation = new LinkOperation ();
    operation.set_main_contact (individual);

    foreach (PersonaAttribute a1 in get_linkable_attributes (persona_to_unlink)) {
      // Check that this attribute actually is used to link this persona to the individual
      bool used_to_link = false;
      foreach (var persona in individual.personas) {
	if (persona != persona_to_unlink &&
	    a1.is_referenced_by_persona (persona)) {
	  used_to_link = true;
	  break;
	}
      }
      if (!used_to_link)
	continue; // Wasn't used, no need to do anything about it

      if (a1.is_removable (persona_to_unlink)) {
	// We can remove the attribute from the persona, which should completely break any linkage
	// due to this attribute
	persona_to_unlink_removals.add (a1);
      } else {
	// We can't remove the attribute from the persona, need to make sure no other persona
	// references this
	other_personas_removals.add (a1);
      }
    }

    // At this point we know how to unlink the persona from the individual, however
    // doing so may cause the remaining personas to form disjoint sets rather than
    // a single Individual. Consider two subsets of personas A and B, and the unlinked
    // persona u which make up the original individual. When unlinking u A and B may be
    // disjoint if:
    // * A links to u and u Links to B, then the data from u that linked it to B was
    //   removed (and no other links go between A and B)
    //  or
    // * A and B both link to u, but to unlink them from u we removed the data in A and
    //   B that caused this link (and no other links go between A and B)
    //
    // To fix this up we need to ensure that all the remaining personas in the inidivudal
    // do have links by picking (or creating if there is none) a persona where all linkable
    // attributes are writeable and ensuring that it can reach all the other remaining
    // personas. We do this the easy way by just adding all linkable attributes to this
    // persona
    var main_persona_additions = PersonaAttribute.create_set ();
    foreach (var p1 in individual.personas) {
      if (p1 == persona_to_unlink)
	continue;
      foreach (PersonaAttribute a2 in get_linkable_attributes (p1)) {
	if (a2 in other_personas_removals)
	  continue;
	main_persona_additions.add (a2);
      }
    }

    // Find tha main persona that will be used to add the extra linking info to
    // avoid disjoint sets
    Persona? main_persona = null;
    foreach (var p2 in individual.personas) {
      if (p2 != persona_to_unlink && persona_can_link_to (p2, main_persona_additions)) {
	main_persona = p2;
	if (main_persona.store.is_primary_store)
	  break; // Exit if we find a primary persona, as we prefer these
      }
    }

    // We make a copy of the personas as the on in the individual may start
    // changing now
    var other_personas = new HashSet<Persona>();
    foreach (var p3 in individual.personas) {
      if (p3 != persona_to_unlink &&
	  p3 != main_persona)
	other_personas.add (p3);
    }

    // If we didn't find a main persona, and we need one because there are
    // other personas that we need to ensure linking in, then create one
    if (main_persona == null && other_personas.size > 1) {
      var details = new HashTable<string, Value?> (str_hash, str_equal);
      try {
        main_persona = yield store.aggregator.primary_store.add_persona_from_details (details);
        yield (main_persona as NameDetails).change_full_name (individual.display_name);
        operation.added_persona (main_persona);
      } catch (GLib.Error e) {
	warning ("Unable to create new persona when unlinking: %s\n", e.message);
	return operation;
      }
    }

    persona_to_unlink.set_data ("contacts-new-contact", true);

    // First apply all additions on the primary persona so that we avoid temporarily being
    // unlinked and then relinked
    if (main_persona != null)
      yield persona_apply_attributes (main_persona, main_persona_additions, other_personas_removals, operation);
    foreach (var p in other_personas) {
      yield persona_apply_attributes (p, null, other_personas_removals, operation);
    }
    // Last we do the removals on the persona_to_unlink
    yield persona_apply_attributes (persona_to_unlink, null, persona_to_unlink_removals, operation);

    persona_to_unlink.set_data ("contacts-new-contact", false);

    return operation;
  }

  public class LinkOperation2 : Object {
    private Store contacts_store;

    /* One Set<Persona> per individual linked, with the intention
     * of restore the old perosonas set on undo operation */
    LinkedList< HashSet<Persona> > old_personas_distribution;

    public LinkOperation2 (Store contacts_store) {
      this.contacts_store = contacts_store;

      old_personas_distribution = new  LinkedList< HashSet<Persona> > ();
    }

    public void add_persona_set (Set<Persona> persona_set) {
      if (persona_set.size > 0) {
	var s = new HashSet<Persona> ();
	foreach (var p in persona_set) {
	  s.add (p);
	}
	old_personas_distribution.add (s);
      }
    }

    public async void undo () {
      Individual ind = null;
      if (old_personas_distribution.size > 0) {
	var ps = old_personas_distribution.first ();
	foreach (var p in ps) {
	  ind = p.individual;
	  break;
	}
      }
      if (ind != null) {
        try {
          yield this.contacts_store.aggregator.unlink_individual (ind);
        } catch (GLib.Error e1) {
          warning ("Error unlinking individual ‘%s’: %s", ind.id, e1.message);
        }
      }

      foreach (var ps in old_personas_distribution) {
        try {
          yield this.contacts_store.aggregator.link_personas (ps);
        } catch (GLib.Error e1) {
          warning ("Error linking personas: %s", e1.message);
        }
      }
    }
  }

  public async LinkOperation2 link_contacts_list (LinkedList<Individual> contact_list, Store contacts_store) {
    var operation = new LinkOperation2 (contacts_store);

    var all_personas = new HashSet<Persona> ();
    foreach (var i in contact_list) {
      var ps = i.personas;
      all_personas.add_all (ps);
      operation.add_persona_set (ps);
    }

    try {
      yield contacts_store.aggregator.link_personas (all_personas);
    } catch (GLib.Error e1) {
      warning ("Error linking personas: %s", e1.message);
    }

    return operation;
  }
}
