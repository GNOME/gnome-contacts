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
using Gee;
using Folks;

public class Contacts.TypeCombo : Grid  {

}

public class Contacts.TypeSet : Object  {
  const int MAX_TYPES = 3;
  private struct InitData {
    unowned string display_name;
    unowned string types[3]; //MAX_TYPES
  }

  private static HashTable<unowned string, GLib.List<InitData *> > hash;

  private TypeSet () {
    hash = new HashTable<unowned string, GLib.List<InitData*> > (str_hash, str_equal);
  }

  private void add_data (InitData *data) {
    unowned GLib.List<InitData *> l = hash.lookup (data.types[0]);
    if (l != null) {
      l.append (data);
    } else {
      GLib.List<InitData *> l2 = null;
      l2.append (data);
      hash.insert (data.types[0], (owned) l2);
    }
  }

  private static TypeSet _general;
  private static TypeSet _phone;

  public static TypeSet general {
    get {
      const InitData[] data = {
	// List most specific first, always in upper case
	{ N_("Home"), { "HOME" } },
	{ N_("Work"), { "WORK" } }
      };

      if (_general == null) {
	_general = new TypeSet ();
	for (int i = 0; i < data.length; i++) {
	  _general.add_data (&data[i]);
	}
      }

      return _general;
    }
  }

  public static TypeSet phone {
    get {
      const InitData[] data = {
	// List most specific first, always in upper case
	{ N_("Assistant"), { "X-EVOLUTION-ASSISTANT" } },
	{ N_("Work"), { "WORK", "VOICE" } },
	// { N_("Business Phone 2"), { "WORK", "VOICE"},  1
	{ N_("Work Fax"), { "WORK", "FAX" } },
	{ N_("Callback"),   { "X-EVOLUTION-CALLBACK" } },
	{ N_("Car"),        { "CAR" } },
	{ N_("Company"),    { "X-EVOLUTION-COMPANY" } },
	{ N_("Home"),       { "HOME", "VOICE" } },
	//{ N_("Home 2"),     { "HOME", "VOICE" } },  1),
	{ N_("Home Fax"),         { "HOME", "FAX" } },
	{ N_("ISDN"),             { "ISDN" } },
	{ N_("Mobile"),     { "CELL" } },
	{ N_("Other"),      { "VOICE" } },
	{ N_("Fax"),        { "FAX" } },
	{ N_("Pager"),            { "PAGER" } },
	{ N_("Radio"),            { "X-EVOLUTION-RADIO" } },
	{ N_("Telex"),            { "X-EVOLUTION-TELEX" } },
	/* To translators: TTY is Teletypewriter */
	{ N_("TTY"),              { "X-EVOLUTION-TTYTDD" } },
	{ N_("Home"), { "HOME" } },
	{ N_("Work"), { "WORK" } }
      };

      if (_phone == null) {
	_phone = new TypeSet ();
	for (int i = 0; i < data.length; i++) {
	  _phone.add_data (&data[i]);
	}
      }

      return _phone;
    }
  }

  private static string? get_first_string (Collection<string> collection) {
    var i = collection.iterator();
    if (i.next())
      return i.get();
    return null;
  }

  private static int get_first_string_as_int (Collection<string> collection) {
    var s = get_first_string (collection);
    if (s == null)
      return int.MAX;
    return int.parse (s);
  }

  public InitData *lookup_data (FieldDetails detail) {
    var i = detail.get_parameter_values ("type");
    if (i == null || i.is_empty)
      return null;

    var list = new Gee.ArrayList<string> ();
    foreach (var s in detail.get_parameter_values ("type")) {
      if (s.ascii_casecmp ("OTHER") == 0 ||
	  s.ascii_casecmp ("INTERNET") == 0 ||
	  s.ascii_casecmp ("PREF") == 0)
	continue;
      list.add (s.up ());
    }

    if (list.is_empty)
      return null;

    list.sort ();

    unowned GLib.List<InitData *>? l = hash.lookup (list[0]);
    foreach (var d in l) {
      bool all_found = true;
      for (int j = 0; j < MAX_TYPES && d.types[j] != null; j++) {
	if (!list.contains (d.types[j])) {
	  all_found = false;
	  break;
	}
      }
      if (all_found)
	return d;
    }

    return null;
  }

  public string format_type (FieldDetails detail) {
    if (detail.parameters.contains ("x-google-label")) {
      return get_first_string (detail.parameters.get ("x-google-label"));
    }

    var d = lookup_data (detail);
    if (d != null) {
      return dgettext (Config.GETTEXT_PACKAGE, d.display_name);
    }

    return _("Other");
  }
}
