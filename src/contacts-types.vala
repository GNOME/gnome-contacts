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
using Gee;
using Folks;

public class Contacts.TypeSet : Object  {
  const string X_GOOGLE_LABEL = "x-google-label";
  const int MAX_TYPES = 3;
  private struct InitData {
    unowned string display_name_u;
    unowned string types[3]; //MAX_TYPES
  }

  private class Data : Object {
    public string display_name; // Translated
    public GLib.List<InitData*> init_data;
    public TreeIter iter; // Set if in_store
    public bool in_store;
  }

  // Dummy Data to mark the "Custom..." store entry
  private static Data custom_dummy = new Data ();
  // Dummy Data to mark the "Other..." store entry
  private static Data other_dummy = new Data ();

  // Map from translated display name to Data for all "standard" types
  private HashTable<unowned string, Data> display_name_hash;
  // Map from all type strings in to list of InitData with the data in it
  private HashTable<unowned string, GLib.List<InitData*> > vcard_lookup_hash;
  // Map from display name to TreeIter for all custom types
  private HashTable<string, TreeIter?> custom_hash;

  public Gtk.ListStore store;
  private TreeIter other_iter;

  private TypeSet () {
    display_name_hash = new HashTable<unowned string, Data> (str_hash, str_equal);
    vcard_lookup_hash = new HashTable<unowned string, GLib.List<InitData*> > (str_hash, str_equal);
    custom_hash = new HashTable<unowned string, TreeIter? > (str_hash, str_equal);

    store = new Gtk.ListStore (2,
                               // Display name or null for separator
                               typeof(string?),
                               // Data for standard types, null for custom
                               typeof (Data));
  }

  private void add_data_to_store (Data data, bool is_custom) {
    if (data.in_store)
      return;

    data.in_store = true;
    if (is_custom)
      store.insert_before (out data.iter, null);
    else
      store.append (out data.iter);

    store.set (data.iter, 0, data.display_name, 1, data);
  }

  private void add_init_data (InitData *init_data) {
    unowned string dn = dgettext (Config.GETTEXT_PACKAGE, init_data.display_name_u);
    Data data = display_name_hash.lookup (dn);
    if (data == null) {
      data = new Data ();
      data.display_name = dn;
      display_name_hash.insert (dn, data);
    }

    data.init_data.append (init_data);

    for (int j = 0; j < MAX_TYPES && init_data.types[j] != null; j++) {
      unowned string type = init_data.types[j];
      unowned GLib.List<InitData*> l = vcard_lookup_hash.lookup (type);
      if (l != null) {
	l.append (init_data);
      } else {
	GLib.List<InitData*> l2 = null;
	l2.append (init_data);
	vcard_lookup_hash.insert (type, (owned) l2);
      }
    }
  }

  private void add_init_data_done (string[] standard_untranslated) {
    foreach (var untranslated in standard_untranslated) {
      var data = display_name_hash.lookup (dgettext (Config.GETTEXT_PACKAGE, untranslated));
      if (data != null)
	add_data_to_store (data, false);
      else
	error ("Internal error: Can't find display name %s in TypeSet data", untranslated);
    }

    store.append (out other_iter);
    /* Refers to the type of the detail, could be Home, Work or Other for email, and the same
     * for phone numbers, addresses, etc. */
    store.set (other_iter, 0, _("Other"), 1, other_dummy);
  }

  public void add_custom_label (string label, out TreeIter iter) {
    // If we add a custom name equal to one of the standard ones, reuse that one
    var data = display_name_hash.lookup (label);
    if (data != null) {
      add_data_to_store (data, true);
      iter = data.iter;
      return;
    }

    if (label == _("Other")) {
      iter = other_iter;
      return;
    }

    unowned TreeIter? iterp = custom_hash.lookup (label);
    if (iterp != null) {
      iter = iterp;
      return;
    }

    store.insert_before (out iter, null);
    store.set (iter, 0, label, 1, null);
    custom_hash.insert (label, iter);
  }

  private unowned Data? lookup_data_by_string (string str) {
    unowned GLib.List<InitData *>? l = vcard_lookup_hash.lookup (str);
    foreach (unowned InitData *d in l) {
      if (d.types[1] == null) {
	unowned string dn = dgettext (Config.GETTEXT_PACKAGE, d.display_name_u);
	return display_name_hash.lookup (dn);
      }
    }

    return null;
  }


  private unowned Data? lookup_data (AbstractFieldDetails detail) {
    var i = detail.get_parameter_values ("type");
    if (i == null || i.is_empty)
      return null;

    var list = new Gee.ArrayList<string> ();
    foreach (var s in detail.get_parameter_values ("type")) {
      list.add (s.up ());
    }

    // Make sure all items in the InitData is in the specified type, there might
    // be more, but we ignore them (so a HOME,FOO,PREF,BLAH contact still matches
    // the standard HOME one, but not HOME,FAX
    unowned GLib.List<InitData *>? l = vcard_lookup_hash.lookup (list[0]);
    foreach (unowned InitData *d in l) {
      bool all_found = true;
      for (int j = 0; j < MAX_TYPES && d.types[j] != null; j++) {
	if (!list.contains (d.types[j])) {
	  all_found = false;
	  break;
	}
      }
      if (all_found) {
	unowned string dn = dgettext (Config.GETTEXT_PACKAGE, d.display_name_u);
	return display_name_hash.lookup (dn);
      }
    }

    return null;
  }

  // Looks up (and creates if necessary) the type in the store
  public void lookup_type (AbstractFieldDetails detail, out TreeIter iter) {
    if (detail.parameters.contains (X_GOOGLE_LABEL)) {
      var label = Utils.get_first<string> (detail.parameters.get (X_GOOGLE_LABEL));
      add_custom_label (label, out iter);
      return;
    }

    unowned Data? d = lookup_data (detail);
    if (d != null) {
      add_data_to_store (d, true);
      iter = d.iter;
    } else {
      iter = other_iter;
    }
  }

  public void lookup_type_by_string (string type, out TreeIter iter) {
    unowned Data? d = lookup_data_by_string (type);
    if (d != null) {
      iter = d.iter;
    } else {
      iter = other_iter;
    }
  }


  public void type_seen (AbstractFieldDetails detail) {
    lookup_type (detail, null);
  }

  public string format_type (AbstractFieldDetails detail) {
    if (detail.parameters.contains (X_GOOGLE_LABEL)) {
      return Utils.get_first<string> (detail.parameters.get (X_GOOGLE_LABEL));
    }

    unowned Data? d = lookup_data (detail);
    if (d != null) {
      return d.display_name;
    }

    return _("Other");
  }

  public void update_type_parameter (MultiMap<string, string> parameters, TreeIter iter) {
    bool has_pref = false;
    foreach (var val in parameters["type"]) {
      if (val.ascii_casecmp ("PREF") == 0) {
        has_pref = true;
        break;
      }
    }

    parameters.remove_all("type");
    parameters.remove_all(X_GOOGLE_LABEL);

    Data data;
    string display_name;
    store.get (iter, 0, out display_name, 1, out data);

    assert (display_name != null); // Not separator
    assert (data != custom_dummy); // Not custom...

    if (data == null) { // A custom label
      parameters["type"] = "OTHER";
      parameters[X_GOOGLE_LABEL] = display_name;
    } else {
      if (data == other_dummy) {
        parameters["type"] = "OTHER";
      } else {
        InitData *init_data = data.init_data.data;
        for (int j = 0; j < MAX_TYPES && init_data.types[j] != null; j++) {
          parameters["type"] = init_data.types[j];
        }
      }
    }

    if (has_pref)
      parameters["type"] = "PREF";
  }

  public bool is_custom (TreeIter iter) {
    Data data;
    store.get (iter, 1, out data);
    return data == custom_dummy;
  }

  private static TypeSet _general;
  private const InitData[] general_data = {
    // List most specific first, always in upper case
    { N_("Home"), { "HOME" } },
    { N_("Work"), { "WORK" } }
  };
  public static TypeSet general {
    get {
      string[] standard = {
	"Work", "Home"
      };

      if (_general == null) {
	_general = new TypeSet ();
	for (int i = 0; i < general_data.length; i++)
	  _general.add_init_data (&general_data[i]);
	_general.add_init_data_done (standard);
      }

      return _general;
    }
  }

  private static TypeSet _email;
  private const InitData[] email_data = {
    // List most specific first, always in upper case
    { N_("Personal"), { "PERSONAL" } },
    { N_("Home"), { "HOME" } },
    { N_("Work"), { "WORK" } }
  };
  public static TypeSet email {
    get {
      string[] standard = {
	"Personal", "Home", "Work"
      };

      if (_email == null) {
	_email = new TypeSet ();
	for (int i = 0; i < email_data.length; i++)
	  _email.add_init_data (&email_data[i]);
	_email.add_init_data_done (standard);
      }

      return _email;
    }
  }

  private static TypeSet _phone;
  public static TypeSet phone {
    get {
      const InitData[] data = {
	// List most specific first, always in upper case
	{ N_("Assistant"), { "X-EVOLUTION-ASSISTANT" } },
	{ N_("Work"), { "WORK", "VOICE" } },
	{ N_("Work Fax"), { "WORK", "FAX" } },
	{ N_("Callback"),   { "X-EVOLUTION-CALLBACK" } },
	{ N_("Car"),        { "CAR" } },
	{ N_("Company"),    { "X-EVOLUTION-COMPANY" } },
	{ N_("Home"),       { "HOME", "VOICE" } },
	{ N_("Home Fax"),         { "HOME", "FAX" } },
	{ N_("ISDN"),             { "ISDN" } },
	{ N_("Mobile"),     { "CELL" } },
	{ N_("Other"),      { "VOICE" } },
	{ N_("Fax"),        { "FAX" } },
	{ N_("Pager"),            { "PAGER" } },
	{ N_("Radio"),            { "X-EVOLUTION-RADIO" } },
	{ N_("Telex"),            { "X-EVOLUTION-TELEX" } },
	/* To translators: TTY is Teletypewriter */
	{ N_("TTY"),              { "X-EVOLUTION-TTYTDD" } }
	// Also we add the general ones here
      };

      // Make sure these strings are the same as the above
      string[] standard = {
	"Mobile", "Work", "Home"
      };

      if (_phone == null) {
	_phone = new TypeSet ();
	for (int i = 0; i < data.length; i++)
	  _phone.add_init_data (&data[i]);
	for (int i = 0; i < general_data.length; i++)
	  _phone.add_init_data (&general_data[i]);
	_phone.add_init_data_done (standard);
      }

      return _phone;
    }
  }
}

public class Contacts.TypeCombo : Grid  {
  TypeSet type_set;
  ComboBox combo;
  Entry entry;
  TreeIter last_active;
  bool custom_mode;
  bool in_manual_change;
  public bool modified;

  public signal void changed ();

  public TypeCombo (TypeSet type_set) {
    this.type_set = type_set;

    combo = new ComboBox.with_model (type_set.store);
    combo.set_halign (Align.FILL);
    combo.set_hexpand (true);
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
    entry.set_halign (Align.FILL);
    entry.set_hexpand (true);
    // Make the default entry small so we don't unnecessarily
    // expand the labels (it'll be expanded a bit anyway)
    entry.width_chars = 4;

    this.add (entry);

    combo.set_no_show_all (true);
    entry.set_no_show_all (true);

    combo.show ();

    combo.changed.connect (combo_changed);
    entry.focus_out_event.connect (entry_focus_out_event);
    entry.activate.connect (entry_activate);
    entry.key_release_event.connect (entry_key_release);
  }

  private void finish_custom () {
    if (!custom_mode)
      return;

    custom_mode = false;
    var text = entry.get_text ();

    if (text != "") {
      TreeIter iter;
      type_set.add_custom_label (text, out iter);

      last_active = iter;
      combo.set_active_iter (iter);
    } else {
      combo.set_active_iter (last_active);
    }

    combo.show ();
    entry.hide ();
  }

  private void entry_activate () {
    finish_custom ();
  }

  private bool entry_key_release (Gdk.EventKey event) {
    if (event.keyval == Gdk.Key.Escape) {
      entry.set_text ("");
      finish_custom ();
    }
    return true;
  }

  private bool entry_focus_out_event (Gdk.EventFocus event) {
    finish_custom ();
    return false;
  }

  private void combo_changed (ComboBox combo) {
    if (in_manual_change)
      return;

    modified = true;
    TreeIter iter;
    if (combo.get_active_iter (out iter)) {
      if (type_set.is_custom (iter)) {
	custom_mode = true;
	entry.show ();
	entry.grab_focus ();
	combo.hide ();
      } else {
	last_active = iter;
	this.changed ();
      }
    }
  }

  private void set_from_iter (TreeIter iter) {
    in_manual_change = true;
    last_active = iter;
    combo.set_active_iter (iter);
    in_manual_change = false;
    modified = false;
  }

  public void set_active (AbstractFieldDetails details) {
    TreeIter iter;
    type_set.lookup_type (details, out iter);
    set_from_iter (iter);
  }

  public void set_to (string type) {
    TreeIter iter;
    type_set.lookup_type_by_string (type, out iter);
    set_from_iter (iter);
  }

  public void update_type_parameter (MultiMap<string, string> parameters) {
    TreeIter iter;
    combo.get_active_iter (out iter);
    type_set.update_type_parameter (parameters, iter);
  }
}
