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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

using Gtk;
using Folks;
using Gee;

public class Contacts.Store : GLib.Object {
  public signal void changed (Contact c);
  public signal void added (Contact c);
  public signal void removed (Contact c);

  public IndividualAggregator aggregator { get; private set; }
  Gee.ArrayList<Contact> contacts;

  public Store () {
    contacts = new Gee.ArrayList<Contact>();

    aggregator = new IndividualAggregator ();
    aggregator.individuals_changed.connect ((added, removed, m, a, r) =>   {
	foreach (Individual i in removed) {
	  this.remove (Contact.from_individual (i));
	}
	foreach (Individual i in added) {
	  var c = new Contact (this, i);
	  this.add (c);
	}
      });
    aggregator.prepare ();
  }

  private void contact_changed_cb (Contact c) {
    changed (c);
  }

  public Contact? find_contact_with_id (string individual_id) {
    foreach (var contact in contacts) {
      if (contact.individual.id == individual_id)
	return contact;
    }
    return null;
  }

  public Contact? find_contact_with_email (string email_address) {
    foreach (var contact in contacts) {
      if (contact.has_email (email_address))
	return contact;
    }
    return null;
  }

  public Contact? find_contact_with_persona (Persona persona) {
    foreach (var contact in contacts) {
      if (contact.individual.personas.contains (persona))
	return contact;
    }
    return null;
  }

  public Collection<Contact> get_contacts () {
    return contacts.read_only_view;
  }

  private void add (Contact c) {
    contacts.add (c);
    c.changed.connect (contact_changed_cb);
    added (c);
  }

  private void remove (Contact c) {
    c.changed.disconnect (contact_changed_cb);

    var i = contacts.index_of (c);
    if (i != contacts.size - 1)
      contacts.set (i, contacts.get (contacts.size - 1));
    contacts.remove_at (contacts.size - 1);

    removed (c);
  }
}
