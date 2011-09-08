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
  internal class LinkData {
    HashMultiMap<string, ImFieldDetails> protocols_addrs_set;
    HashMultiMap<string, WebServiceFieldDetails> web_service_addrs_set;
    Gee.HashSet<string> local_ids;

    public LinkData () {
      protocols_addrs_set = new HashMultiMap<string, ImFieldDetails>(null, null,
								     (GLib.HashFunc) ImFieldDetails.hash,
								     (GLib.EqualFunc) ImFieldDetails.equal);
      web_service_addrs_set = new HashMultiMap<string, WebServiceFieldDetails> (null, null,
										(GLib.HashFunc) WebServiceFieldDetails.hash,
										(GLib.EqualFunc) WebServiceFieldDetails.equal);
      local_ids = new Gee.HashSet<string> ();
    }

    public void add_link_data_for_persona (Persona persona) {
      if (persona is ImDetails)  {
	ImDetails im_details = (ImDetails) persona;

	/* protocols_addrs_set = union (all personas' IM addresses) */
	foreach (var protocol in im_details.im_addresses.get_keys ()) {
	  var im_addresses = im_details.im_addresses.get (protocol);
	  foreach (var im_address in im_addresses) {
	    protocols_addrs_set.set (protocol, im_address);
	  }
	}
      }

      if (persona is WebServiceDetails) {
	WebServiceDetails ws_details = (WebServiceDetails) persona;

	/* web_service_addrs_set = union (all personas' WS addresses) */
	foreach (var web_service in
		 ws_details.web_service_addresses.get_keys ()) {
	  var ws_addresses = ws_details.web_service_addresses.get (web_service);
	  foreach (var ws_fd in ws_addresses) {
	    web_service_addrs_set.set (web_service, ws_fd);
	  }
	}
      }

      if (persona is LocalIdDetails) {
	foreach (var id in ((LocalIdDetails) persona).local_ids) {
	  local_ids.add (id);
	}
      }
    }

    public void add_link_data_for_individual (Individual individual) {
      foreach (var persona in individual.personas)
      add_link_data_for_persona (persona);
    }

    public void remove_known_link_data (Persona persona) {
      if (persona is ImDetails)  {
	ImDetails im_details = (ImDetails) persona;

	/* protocols_addrs_set = union (all personas' IM addresses) */
	foreach (var protocol in im_details.im_addresses.get_keys ()) {
	  var im_addresses = im_details.im_addresses.get (protocol);
	  foreach (var im_address in im_addresses) {
	    protocols_addrs_set.remove (protocol, im_address);
	  }
	}
      }

      if (persona is WebServiceDetails) {
	WebServiceDetails ws_details = (WebServiceDetails) persona;

	/* web_service_addrs_set = union (all personas' WS addresses) */
	foreach (var web_service in
		 ws_details.web_service_addresses.get_keys ()) {
	  var ws_addresses = ws_details.web_service_addresses.get (web_service);
	  foreach (var ws_fd in ws_addresses) {
	    web_service_addrs_set.remove (web_service, ws_fd);
	  }
	}
      }

      if (persona is LocalIdDetails) {
	foreach (var id in ((LocalIdDetails) persona).local_ids) {
	  local_ids.remove (id);
	}
      }
    }

    public HashTable<string, Value?> get_link_details () {
      var details = new HashTable<string, Value?> (str_hash, str_equal);

      if (protocols_addrs_set.size > 0) {
	var im_addresses_value = Value (typeof (MultiMap));
	im_addresses_value.set_object (protocols_addrs_set);
	details.insert (PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES),
			im_addresses_value);
      }

      if (web_service_addrs_set.size > 0) {
	var web_service_addresses_value = Value (typeof (MultiMap));
	web_service_addresses_value.set_object (web_service_addrs_set);
	details.insert (PersonaStore.detail_key
			(PersonaDetail.WEB_SERVICE_ADDRESSES),
			web_service_addresses_value);
      }

      if (local_ids.size > 0) {
	var local_ids_value = Value (typeof (Set<string>));
	local_ids_value.set_object (local_ids);
	details.insert (
	  Folks.PersonaStore.detail_key (PersonaDetail.LOCAL_IDS),
	  local_ids_value);
      }
      return details;
    }

    private void get_values_for_updating_persona (Persona persona,
						  out MultiMap<string, ImFieldDetails>? im_value,
						  out MultiMap<string, WebServiceFieldDetails>? web_value,
						  out Set<string>? local_value) {
      im_value = null;
      web_value = null;
      local_value = null;

      if (protocols_addrs_set.size > 0 && persona is ImDetails)  {
	ImDetails im_details = (ImDetails) persona;

	im_value = new HashMultiMap<string, ImFieldDetails>(null, null,
							    (GLib.HashFunc) ImFieldDetails.hash,
							    (GLib.EqualFunc) ImFieldDetails.equal);

	foreach (var protocol in im_details.im_addresses.get_keys ()) {
	  var im_addresses = im_details.im_addresses.get (protocol);
	  foreach (var im_address in im_addresses) {
	    im_value.set (protocol, im_address);
	  }
	}
	foreach (var protocol in protocols_addrs_set.get_keys ()) {
	  var im_addresses = protocols_addrs_set.get (protocol);
	  foreach (var im_address in im_addresses) {
	    im_value.set (protocol, im_address);
	  }
	}
      }

      if (web_service_addrs_set.size > 0 && persona is WebServiceDetails) {
	WebServiceDetails ws_details = (WebServiceDetails) persona;

	web_value = new HashMultiMap<string, WebServiceFieldDetails> (null, null,
								      (GLib.HashFunc) WebServiceFieldDetails.hash,
								      (GLib.EqualFunc) WebServiceFieldDetails.equal);

	foreach (var web_service in
		 ws_details.web_service_addresses.get_keys ()) {
	  var ws_addresses = ws_details.web_service_addresses.get (web_service);
	  foreach (var ws_fd in ws_addresses) {
	    web_value.set (web_service, ws_fd);
	  }
	}
	foreach (var web_service in
		 web_service_addrs_set.get_keys ()) {
	  var ws_addresses = web_service_addrs_set.get (web_service);
	  foreach (var ws_fd in ws_addresses) {
	    web_value.set (web_service, ws_fd);
	  }
	}
      }

      if (local_ids.size > 0 && persona is LocalIdDetails) {
	local_value = new Gee.HashSet<string> ();

	var local_details = (LocalIdDetails) persona;
	local_value.add_all (local_details.local_ids);
	local_value.add_all (local_ids);
      }
    }

    public async void apply_to_persona (Persona persona) {
      MultiMap<string, ImFieldDetails>? im_value = null;
      MultiMap<string, WebServiceFieldDetails>? web_value = null;
      Set<string>? local_value = null;

      get_values_for_updating_persona (persona,
				       out im_value, out web_value, out local_value);
      if (im_value != null) {
	try {
	  yield (persona as ImDetails).change_im_addresses (im_value);
	} catch (GLib.Error e1) {
	  warning ("Unable to set im address when linking: %s\n", e1.message);
	}
      }
      if (web_value != null) {
	try {
	  yield (persona as WebServiceDetails).change_web_service_addresses (web_value);
	} catch (GLib.Error e2) {
	  warning ("Unable to set web service when linking: %s\n", e2.message);
	}
      }
      if (local_value != null) {
	try {
	  yield (persona as LocalIdDetails).change_local_ids (local_value);
	} catch (GLib.Error e3) {
	  warning ("Unable to set local ids when linking: %s\n", e3.message);
	}
      }
    }
  }

  public async void link_contacts (Contact main, Contact other) {
    // This should not be used as being replaced with the new individual
    // instead we should always pick this contact to keep around
    other.individual.set_data ("contacts-not-replaced", true);

    var link_data = new LinkData ();
    Persona? writable_persona = null;
    Persona? primary = main.find_primary_persona ();
    Persona? other_primary = other.find_primary_persona ();
    if (primary != null) {
      link_data.add_link_data_for_individual (other.individual);
      writable_persona = primary;
    } else if (other_primary != null) {
      link_data.add_link_data_for_individual (main.individual);
      writable_persona = other_primary;
    } else {
      link_data.add_link_data_for_individual (other.individual);
      link_data.add_link_data_for_individual (main.individual);
      var details = link_data.get_link_details ();

      var name = Value (typeof (string));
      name.set_string (main.display_name);
      details.insert (PersonaStore.detail_key (PersonaDetail.FULL_NAME),
		      name);
      try {
	yield main.store.aggregator.add_persona_from_details (null,
							      main.store.aggregator.primary_store, details);
      } catch (GLib.Error e) {
	warning ("Unable to create new persona when linking: %s\n", e.message);
      }
      writable_persona = null;
    }

    if (writable_persona != null) {
      link_data.remove_known_link_data (writable_persona);
      yield link_data.apply_to_persona (writable_persona);
    }
  }
}
