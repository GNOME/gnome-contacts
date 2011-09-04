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
using TelepathyGLib;

public class Contacts.Store : GLib.Object {
  public signal void changed (Contact c);
  public signal void added (Contact c);
  public signal void removed (Contact c);

  public IndividualAggregator aggregator { get; private set; }
  Gee.ArrayList<Contact> contacts;

  public Gee.HashMap<string, Account> calling_accounts;

  public bool can_call {
    get {
      return this.calling_accounts.size > 0 ? true : false;
    }
  }

  public Store () {
    contacts = new Gee.ArrayList<Contact>();

    aggregator = new IndividualAggregator ();
    aggregator.individuals_changed.connect ((added, removed, m, a, r) =>   {
	var old_individuals = new HashMap<Persona, Individual>();
	var replaced_individuals = new HashSet<Individual>();

	/* Try to reverse engineer which added individuals just replaces
	   old individuals */

	foreach (Individual i in removed) {
	  foreach (var p in i.personas)  {
	    old_individuals.set (p, i);
	  }
	}

	foreach (Individual i in added) {
	  Individual? old_individual = null;
	  foreach (var p in i.personas)  {
	    var o_i = old_individuals.get (p);
	    if (o_i != null) {
	      if (old_individual == null)
		old_individual = o_i;
	      else if (o_i != old_individual) {
		old_individual = null;
		break;
	      }
	    }
	  }
	  if (old_individual != null &&
	      !replaced_individuals.contains (old_individual)) {
	    replaced_individuals.add (old_individual);
	    var c = Contact.from_individual (old_individual);
	    c.replace_individual (i);
	  } else {
	    var c = new Contact (this, i);
	    this.add (c);
	  }
	}

	foreach (Individual i in removed) {
	  if (!replaced_individuals.contains (i)) {
	    this.remove (Contact.from_individual (i));
	  }
	}
      });
    aggregator.prepare ();

    check_call_capabilities ();
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

  public bool is_empty () {
    foreach (var contact in contacts) {
      if (!contact.is_hidden ())
	return false;
    }
    return true;
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

  // TODO: listen for changes in Account#URISchemes
  private async void check_call_capabilities () {
    this.calling_accounts = new Gee.HashMap<string, Account> ();
    var account_manager = AccountManager.dup ();

    try {
      yield account_manager.prepare_async (null);

      account_manager.account_enabled.connect (this.check_account_caps);
      account_manager.account_disabled.connect (this.check_account_caps);

      foreach (var account in account_manager.get_valid_accounts ()) {
	yield this.check_account_caps (account);
      }
    } catch (GLib.Error e) {
      warning ("Unable to check accounts caps %s", e.message);
    }
  }

  private async void check_account_caps (Account account) {
    GLib.Quark addressing = Account.get_feature_quark_addressing ();
    if (!account.is_prepared (addressing)) {
      GLib.Quark[] features = { addressing };
      try {
	yield account.prepare_async (features);
      } catch (GLib.Error e) {
	warning ("Unable to prepare account %s", e.message);
      }
    }

    if (account.is_prepared (addressing)) {
      var k = account.get_object_path ();
      if (account.is_enabled () &&
	  account.associated_with_uri_scheme ("tel")) {
	this.calling_accounts.set (k, account);
      } else {
	this.calling_accounts.unset (k);
      }
    }
  }
}
