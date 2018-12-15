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

public class Contacts.TypeCombo : Grid  {
  private unowned TypeSet type_set;
  private ComboBox combo;
  private Entry entry;
  private TreeIter last_active;
  private bool custom_mode;
  private bool in_manual_change;
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
      type_set.get_iter_for_custom_label (text, out iter);

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
      last_active = iter;
      this.changed ();
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
    type_set.get_iter_for_field_details (details, out iter);
    set_from_iter (iter);
  }

  public void set_to (string type) {
    TreeIter iter;
    type_set.get_iter_for_vcard_type (type, out iter);
    set_from_iter (iter);
  }

  public void update_details (AbstractFieldDetails details) {
    TreeIter iter;
    combo.get_active_iter (out iter);

    TypeDescriptor descriptor;
    string display_name;
    combo.model.get (iter, 0, out display_name, 1, out descriptor);
    assert (display_name != null); // Not separator
    descriptor.save_to_field_details (details);
  }
}
