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
  public signal void quiescent ();

  public IndividualAggregator aggregator { get; private set; }
  Gee.ArrayList<Contact> contacts;

  public Gee.HashMap<string, Account> calling_accounts;

  public bool can_call {
    get {
      return this.calling_accounts.size > 0 ? true : false;
    }
  }

  public bool is_quiescent
    {
      get { return this.aggregator.is_quiescent; }
    }

  public Store () {
    contacts = new Gee.ArrayList<Contact>();

    aggregator = new IndividualAggregator ();
    aggregator.notify["is-quiescent"].connect ( (obj, pspec) => {
	// We seem to get this before individuals_changed, so hack around it
	Idle.add( () => {
	    this.quiescent ();
	    return false;
	  });
      });
    aggregator.individuals_changed_detailed.connect ( (changes) =>   {
	var new_seen = new HashSet<Individual> ();
	foreach (var old_individual in changes.get_keys ()) {
	  var replacements = changes.get (old_individual);
	  if (replacements.is_empty) {
	    this.remove (Contact.from_individual (old_individual));
	  } else {
	    bool found_one_replacement = false;
	    // Note: Apparently the current implementation doesn't necessarily pick
	    // up unlinked individual as replacements.
	    foreach (var replacement in replacements) {
	      if (new_seen.contains (replacement))
		continue;
	      new_seen.add (replacement);
	      if (old_individual != null &&
		  !found_one_replacement
		  /* TODO: && !has-unlinked-persona */) {
		found_one_replacement = true;
		var c = Contact.from_individual (old_individual);
		if (c != null) {
		  c.replace_individual (replacement);
		} else {
		  // TODO: This should not really happen, but seems to do anyway
		  this.add (new Contact (this, replacement));
		}
	      } else {
		this.add (new Contact (this, replacement));
	      }
	    }
	  }
	}
      });
    aggregator.prepare ();

    check_call_capabilities ();
  }

  private void contact_changed_cb (Contact c) {
    changed (c);
  }

  public delegate bool ContactMatcher (Contact c);
  public async Contact? find_contact (ContactMatcher matcher) {
    foreach (var c in contacts) {
      if (matcher (c))
	return c;
    }
    if (is_quiescent)
      return null;

    Contact? matched = null;
    ulong id1, id2, id3;
    SourceFunc callback = find_contact.callback;
    id1 = this.changed.connect ( (c) => {
	if (matcher (c)) {
	  matched = c;
	  callback ();
	}
      });
    id2 = this.added.connect ( (c) => {
	if (matcher (c)) {
	  matched = c;
	  callback ();
	}
      });
    id3 = this.quiescent.connect ( () => {
	callback();
      });
    yield;
    this.disconnect (id1);
    this.disconnect (id2);
    this.disconnect (id3);
    return matched;
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
