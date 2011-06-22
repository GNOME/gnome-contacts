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
  TypeSet type_set;
  ComboBox combo;
  Entry entry;
  bool custom_mode;

  public TypeCombo (TypeSet type_set) {
    this.type_set = type_set;

    combo = new ComboBox.with_model (type_set.store);
    this.add (combo);

    var renderer = new CellRendererText ();
    combo.pack_start (renderer, true);
    combo.set_attributes (renderer,
			  "text", 0);
    combo.set_row_separator_func ( (model, iter) => {
	string? s;
	model.get (iter, 0, out s);
	return s == null;
      });

    entry = new Entry ();
    entry.width_chars = 10;

    this.add (entry);

    combo.set_no_show_all (true);
    entry.set_no_show_all (true);

    combo.show ();

    combo.changed.connect (combo_changed);
    entry.focus_out_event.connect (entry_focus_out_event);
    entry.activate.connect (entry_activate);
  }

  private void finish_custom () {
    if (!custom_mode)
      return;

    custom_mode = false;
    var text = entry.get_text ();

    TreeIter iter;
    type_set.add_custom_label (text, out iter);

    combo.set_active_iter (iter);

    combo.show ();
    entry.hide ();
  }

  private void entry_activate () {
    finish_custom ();
  }

  private bool entry_focus_out_event (Gdk.EventFocus event) {
    finish_custom ();
    return false;
  }

  private void combo_changed (ComboBox combo) {
    TreeIter iter;
    if (combo.get_active_iter (out iter) &&
	type_set.is_custom (iter)) {
      custom_mode = true;
      combo.hide ();
      entry.show ();
      entry.grab_focus ();
    }
  }

  public void set_active (FieldDetails details) {
    TreeIter iter;
    type_set.lookup_detail (details, out iter);
    combo.set_active_iter (iter);
  }
}

public class Contacts.TypeSet : Object  {
  const int MAX_TYPES = 3;
  private struct Data {
    InitData *init_data;
    TreeIter iter;
  }
  private struct InitData {
    unowned string display_name;
    unowned string types[3]; //MAX_TYPES
  }

  static InitData custom_dummy;

  private HashTable<unowned string, GLib.List<Data?> > hash;
  private HashTable<unowned string, TreeIter?> custom_hash;
  public ListStore store;
  private TreeIter other_iter;
  private TreeIter custom_iter;

  private TypeSet () {
    hash = new HashTable<unowned string, GLib.List<Data?> > (str_hash, str_equal);
    custom_hash = new HashTable<unowned string, TreeIter? > (str_hash, str_equal);
    store = new ListStore (2, typeof(string?), typeof (InitData *));
  }

  private void add_data (InitData *init_data) {
    Data data = Data();
    data.init_data = init_data;
    store.append (out data.iter);
    store.set (data.iter, 0, dgettext (Config.GETTEXT_PACKAGE, init_data.display_name), 1, data);

    unowned GLib.List<Data?> l = hash.lookup (init_data.types[0]);
    if (l != null) {
      l.append (data);
    } else {
      GLib.List<Data?> l2 = null;
      l2.append (data);
      hash.insert (init_data.types[0], (owned) l2);
    }
  }

  private void add_data_done () {
    store.append (out other_iter);
    store.set (other_iter, 0, _("Other"), 1, null);

    TreeIter iter;
    store.append (out iter);
    store.set (iter, 0, null);
    store.append (out custom_iter);
    store.set (custom_iter, 0, _("Custom..."), 1, custom_dummy);
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
	_general.add_data_done ();
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
	_phone.add_data_done ();
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

  private unowned Data? lookup_data (FieldDetails detail) {
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

    unowned GLib.List<Data?>? l = hash.lookup (list[0]);
    foreach (unowned Data? d in l) {
      bool all_found = true;
      for (int j = 0; j < MAX_TYPES && d.init_data.types[j] != null; j++) {
	if (!list.contains (d.init_data.types[j])) {
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

    unowned Data? d = lookup_data (detail);
    if (d != null) {
      return dgettext (Config.GETTEXT_PACKAGE, d.init_data.display_name);
    }

    return _("Other");
  }

  public void lookup_detail (FieldDetails detail, out TreeIter iter) {
    if (detail.parameters.contains ("x-google-label")) {
      var label = get_first_string (detail.parameters.get ("x-google-label"));
      add_custom_label (label, out iter);
      return;
    }

    unowned Data? d = lookup_data (detail);
    if (d != null)
      iter = d.iter;
    else
      iter = other_iter;
  }

  public bool is_custom (TreeIter iter) {
    InitData *data;
    store.get (iter, 1, out data);
    return data == &custom_dummy;
  }

  public void add_custom_label (string label, out TreeIter iter) {
    unowned TreeIter? iterp = custom_hash.lookup (label);
    if (iterp != null) {
      iter = iterp;
      return;
    }
    store.insert_before (out iter, custom_iter);
    store.set (iter, 0, label, 1, null);
    custom_hash.insert (label, iter);
  }
}
