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
 * The ContactList is the actual list of {@link Individual}s that the user sees on
 * the left. It is contained by the {@link ListPane}, which also provides other
 * functionality, such as an action bar.
 */
public class Contacts.ContactList : Gtk.ListBox {
  private class ContactDataRow : Gtk.ListBoxRow {
    private const int LIST_AVATAR_SIZE = 48;

    public Individual individual;
    private Gtk.Label label;
    private Avatar avatar;
    public Gtk.CheckButton selector_button;
    // Whether the selector should always be visible (or only on hover)
    private bool checkbox_exposed = false;

    public ContactDataRow(Individual i) {
      this.individual = i;
      this.individual.notify.connect (on_contact_changed);

      get_style_context (). add_class ("contact-data-row");

      Gtk.Grid grid = new Gtk.Grid ();
      grid.margin = 3;
      grid.margin_start = 9;
      grid.set_column_spacing (10);
      this.avatar = new Avatar (LIST_AVATAR_SIZE, this.individual);

      this.label = new Gtk.Label (individual.display_name);
      this.label.ellipsize = Pango.EllipsizeMode.END;
      this.label.valign = Gtk.Align.CENTER;
      this.label.halign = Gtk.Align.START;
      // Make sure it doesn't "twitch" when the checkbox becomes visible
      this.label.xalign = 0;

      this.selector_button = new Gtk.CheckButton ();
      this.selector_button.visible = false;
      this.selector_button.valign = Gtk.Align.CENTER;
      this.selector_button.halign = Gtk.Align.END;
      this.selector_button.hexpand = true;
      // Make sure it doesn't overlap with the scrollbar
      this.selector_button.margin_end = 12;

      grid.attach (this.avatar, 0, 0);
      grid.attach (this.label, 1, 0);
      grid.attach (this.selector_button, 2, 0);
      this.add (grid);
      this.show_all ();
    }

    private void on_contact_changed (Object obj, ParamSpec pspec) {
      //TODO: Update also the Avatar
      this.label.set_text (this.individual.display_name);
      changed ();
    }

    // Sets whether the checbox should always be shown (and not only on hover)
    public void expose_checkbox (bool expose) {
      this.checkbox_exposed = expose;

      var hovering = Gtk.StateFlags.PRELIGHT in get_state_flags ();
      this.selector_button.visible = expose || hovering;
    }

    // Normally, we would use the (enter/leave)_notify_event here, but since ListBoxRow
    // doesn't have its own Gdk.Window, this won't work (at least in GTK+3).
    public override void state_flags_changed (Gtk.StateFlags previous_state) {
      var hovering_now = Gtk.StateFlags.PRELIGHT in get_state_flags ();
      var was_hovering = Gtk.StateFlags.PRELIGHT in previous_state;

      if (hovering_now != was_hovering) // If hovering changed
        this.selector_button.visible = checkbox_exposed || hovering_now;
    }
  }

  public signal void selection_changed (Individual? individual);
  public signal void contacts_marked (int contacts_marked);

  int nr_contacts_marked = 0;

  private Query filter_query;

  private Store store;

  private bool sort_on_surname = false; // keep in sync with the setting

  public UiState state { get; set; }

  public ContactList (Settings settings, Store store, Query query) {
    this.selection_mode = Gtk.SelectionMode.BROWSE;
    this.store = store;
    this.filter_query = query;
    this.filter_query.notify.connect (() => { invalidate_filter (); });
    this.visible = true;

    this.notify["state"].connect (on_ui_state_changed);

    this.sort_on_surname = settings.sort_on_surname;
    settings.changed["sort-on-surname"].connect(() => {
        this.sort_on_surname = settings.sort_on_surname;
        invalidate_sort();
      });

    this.store.added.connect (contact_added_cb);
    this.store.removed.connect (contact_removed_cb);
    foreach (var i in this.store.get_contacts ())
      contact_added_cb (this.store, i);

    get_style_context ().add_class ("contacts-contact-list");

    set_sort_func (compare_rows);
    set_filter_func (filter_row);
    set_header_func (update_header);
  }

  private void on_ui_state_changed (Object obj, ParamSpec pspec) {
    foreach (var widget in get_children ()) {
      var row = widget as ContactDataRow;
      row.expose_checkbox (this.state == UiState.SELECTING);

      if (this.state != UiState.SELECTING)
        row.selector_button.active = false;
    }

    if (this.state != UiState.SELECTING)
      this.nr_contacts_marked = 0;
  }

  private int compare_rows (Gtk.ListBoxRow row_a, Gtk.ListBoxRow row_b) {
    var a = ((ContactDataRow) row_a).individual;
    var b = ((ContactDataRow) row_b).individual;

    // Always prefer favourites over non-favourites.
    if (a.is_favourite != b.is_favourite)
      return a.is_favourite? -1 : 1;

    // Both are (non-)favourites: sort by either first name or surname (user preference)
    unowned string? a_name = this.sort_on_surname? try_get_surname(a) : a.display_name;
    unowned string? b_name = this.sort_on_surname? try_get_surname(b) : b.display_name;

    return a_name.collate (b_name);
  }

  private unowned string try_get_surname (Individual indiv) {
    if (indiv.structured_name != null && indiv.structured_name.family_name != "")
      return indiv.structured_name.family_name;

    // Fall back to the display_name
    return indiv.display_name;
  }

  private void update_header (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
    var current = ((ContactDataRow) row).individual;

    if (before == null) {
      if (current.is_favourite)
        row.set_header (create_header_label (_("Favorites")));
      else
        row.set_header (create_header_label (_("All Contacts")));
      return;
    }

    var previous = ((ContactDataRow) before).individual;
    if (!current.is_favourite && previous.is_favourite) {
      row.set_header (create_header_label (_("All Contacts")));
    } else {
      row.set_header (null);
    }
  }

  private Gtk.Label create_header_label (string text) {
    var label = new Gtk.Label (text);
    label.halign = Gtk.Align.START;
    label.margin = 3;
    label.margin_start = 6;
    label.margin_top = 6;
    var attrs = new Pango.AttrList ();
    attrs.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
    attrs.insert (Pango.attr_scale_new ((Pango.Scale.SMALL + Pango.Scale.MEDIUM) / 2.0));
    attrs.insert (Pango.attr_foreground_alpha_new (30000));
    label.attributes = attrs;
    return label;
  }

  private void contact_added_cb (Store store, Individual i) {
    // Don't create a row for ignorable contacts are the individual already has a row
    if (!Contacts.Utils.is_ignorable (i) && find_row_for_contact(i) == null) {
      var row =  new ContactDataRow (i);
      row.selector_button.toggled.connect ( () => { on_row_checkbox_toggled (row); });
      row.selector_button.visible = (this.state == UiState.SELECTING);

      add (row);
    } else {
      debug ("Contact %s was ignored", i.id);
    }
  }

  private void on_row_checkbox_toggled (ContactDataRow row) {
    this.nr_contacts_marked += (row.selector_button.active)? 1 : -1;

    // User selected a first checkbox: enter selection mode
    if (row.selector_button.active && this.nr_contacts_marked == 1)
      this.state = UiState.SELECTING;


    // User deselected the last checkbox: leave selection mode
    if (!row.selector_button.active && this.nr_contacts_marked == 0)
      this.state = UiState.SHOWING;

    contacts_marked (this.nr_contacts_marked);
  }

  private void contact_removed_cb (Store store, Individual i) {
    var row = find_row_for_contact (i);
    if (row != null)
      row.destroy ();
  }

  public override void row_selected (Gtk.ListBoxRow? row) {
    var data = (ContactDataRow?) row as ContactDataRow;
    var individual = data != null ? data.individual : null;
    selection_changed (individual);
#if HAVE_TELEPATHY
    if (individual != null)
      Utils.fetch_contact_info (individual);
#endif
  }

  private bool filter_row (Gtk.ListBoxRow row) {
    var individual = ((ContactDataRow) row).individual;
    return this.filter_query.is_match (individual) > 0;
  }

  public void select_contact (Individual? individual) {
    if (individual == null) {
      /* deselect */
      select_row (null);
      return;
    }

    select_row (find_row_for_contact (individual));
  }

  public void hide_contact (Individual? individual) {
    if (individual != null) {
      find_row_for_contact (individual).hide ();
    }
  }


  private ContactDataRow? find_row_for_contact (Individual individual) {
    foreach (var widget in get_children ()) {
      var row = ((ContactDataRow) widget);
      if (row.individual == individual)
        return row;
    }

    return null;
  }

  public LinkedList<Individual> get_marked_contacts () {
    var cs = new LinkedList<Individual> ();
    foreach (var widget in get_children ()) {
      var row = widget as ContactDataRow;
      if (row.selector_button.active)
        cs.add (row.individual);
    }
    return cs;
  }

  public LinkedList<Individual> get_marked_contacts_and_hide () {
    var cs = new LinkedList<Individual> ();
    foreach (var widget in get_children ()) {
      var row = widget as ContactDataRow;
      if (row.selector_button.active) {
        row.visible = false;
        cs.add (row.individual);
      }
    }
    return cs;
  }


  public override bool button_press_event (Gdk.EventButton event) {
    base.button_press_event (event);

    if (event.button == Gdk.BUTTON_SECONDARY) {
      var row = (ContactDataRow) get_row_at_y ((int) Math.round (event.y));
      if (row != null) {
        select_row (row);
        row.selector_button.active = this.state != UiState.SELECTING || !row.selector_button.active;
      }
    }

    return false;
  }
}
