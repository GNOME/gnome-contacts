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

/**
 * The ContactList is the actual list of {@link Individual}s that the user sees on
 * the left. It is contained by the {@link ListPane}, which also provides other
 * functionality, such as an action bar.
 */
public class Contacts.ContactList : Adw.Bin {

  int nr_contacts_marked = 0;

  private Query filter_query;

  private Store store;

  private bool sort_on_surname = false; // keep in sync with the setting

  private bool got_long_press = false;

  public UiState state { get; set; }

  private unowned Gtk.ListBox listbox;

  // The vertical adjustment of the scrolled window
  private unowned Gtk.Adjustment vadjustment;

  public signal void selection_changed (Individual? individual);
  public signal void contacts_marked (int contacts_marked);

  construct {
    // First construct a ScrolledWindow with a Viewport
    var sw = new Gtk.ScrolledWindow ();
    sw.hscrollbar_policy = Gtk.PolicyType.NEVER;
    sw.add_css_class ("contact-list-scrolled-window");
    this.vadjustment = sw.vadjustment;
    sw.vadjustment.value_changed.connect ((vadj) => { this.load_visible_avatars (); });
    this.child = sw;

    var viewport = new Gtk.Viewport (sw.hadjustment, sw.vadjustment);
    viewport.scroll_to_focus = true;
    sw.set_child (viewport);

    // Then create the listbox
    var list_box = new Gtk.ListBox ();
    this.listbox = list_box;
    viewport.set_child (list_box);

    this.listbox.selection_mode = Gtk.SelectionMode.BROWSE;
    this.listbox.set_sort_func (compare_rows);
    this.listbox.set_filter_func (filter_row);
    this.listbox.set_header_func (update_header);
    this.listbox.add_css_class ("navigation-sidebar");

    this.add_css_class ("contacts-contact-list");

    // Row selection/activation
    this.listbox.row_activated.connect (on_row_activated);
    this.listbox.row_selected.connect (on_row_selected);

    // Connect events right-click and long-press
    var secondary_click_gesture = new Gtk.GestureClick ();
    secondary_click_gesture.button = Gdk.BUTTON_SECONDARY;
    secondary_click_gesture.pressed.connect (on_right_click);
    this.listbox.add_controller (secondary_click_gesture);

    var long_press_gesture = new Gtk.GestureLongPress ();
    long_press_gesture.pressed.connect (on_long_press);
    this.listbox.add_controller (long_press_gesture);
  }

  public ContactList (Settings settings,
                      Store    store,
                      Query    query) {
    this.store = store;
    this.filter_query = query;
    this.filter_query.notify.connect (() => { this.listbox.invalidate_filter ();
                                      });

    this.notify["state"].connect (on_ui_state_changed);

    this.sort_on_surname = settings.sort_on_surname;
    settings.changed["sort-on-surname"].connect (() => {
      this.sort_on_surname = settings.sort_on_surname;
      this.listbox.invalidate_sort ();
    });

    this.store.added.connect (contact_added_cb);
    this.store.removed.connect (contact_removed_cb);
    foreach (var i in this.store.get_contacts ())
      contact_added_cb (this.store, i);
  }

  private void on_ui_state_changed (Object obj, ParamSpec pspec) {
    for (int i = 0; true; i++) {
      unowned var row = (ContactDataRow) this.listbox.get_row_at_index (i);
      if (row == null)
        break;

      row.selector_button.visible = (this.state == UiState.SELECTING);

      if (this.state != UiState.SELECTING)
        row.selector_button.active = false;
    }

    // Disalbe highlighted (blue) selection since we use the checkbox to show selection
    if (this.state == UiState.SELECTING) {
      this.listbox.selection_mode = Gtk.SelectionMode.NONE;
    } else {
      this.listbox.selection_mode = Gtk.SelectionMode.BROWSE;
      this.nr_contacts_marked = 0;
    }
  }

  private int compare_rows (Gtk.ListBoxRow row_a, Gtk.ListBoxRow row_b) {
    unowned var a = ((ContactDataRow) row_a).individual;
    unowned var b = ((ContactDataRow) row_b).individual;

    // Always prefer favourites over non-favourites.
    if (a.is_favourite != b.is_favourite)
      return a.is_favourite? -1 : 1;

    // Both are (non-)favourites: sort by either first name or surname (user preference)
    unowned var a_name = this.sort_on_surname? try_get_surname (a) : a.display_name;
    unowned var b_name = this.sort_on_surname? try_get_surname (b) : b.display_name;

    return a_name.collate (b_name);
  }

  private unowned string try_get_surname (Individual indiv) {
    if (indiv.structured_name != null && indiv.structured_name.family_name != "")
      return indiv.structured_name.family_name;

    // Fall back to the display_name
    return indiv.display_name;
  }

  private void update_header (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
    unowned var current = ((ContactDataRow) row).individual;

    if (before == null) {
      if (current.is_favourite)
        row.set_header (create_header_label (_("Favorites")));
      else
        row.set_header (create_header_label (_("All Contacts")));
      return;
    }

    unowned var previous = ((ContactDataRow) before).individual;
    if (!current.is_favourite && previous.is_favourite) {
      row.set_header (create_header_label (_("All Contacts")));
    } else {
      row.set_header (null);
    }
  }

  private Gtk.Label create_header_label (string text) {
    var label = new Gtk.Label (text);
    label.halign = Gtk.Align.START;
    label.margin_start = 6;
    label.margin_end = 3;
    label.margin_top = 6;
    label.margin_bottom = 3;
    label.add_css_class ("heading");
    label.add_css_class ("dim-label");
    return label;
  }

  private void contact_added_cb (Store store, Individual i) {
    // Don't create a row for ignorable contacts are the individual already has a row
    if (!Contacts.Utils.is_ignorable (i) && find_row_for_contact(i) == null) {
      var row =  new ContactDataRow (i);
      row.selector_button.toggled.connect (() => { on_row_checkbox_toggled (row); });
      row.selector_button.visible = (this.state == UiState.SELECTING);

      this.listbox.append (row);
    } else {
      debug ("Contact %s was ignored", i.id);
    }
  }

  private void on_row_checkbox_toggled (ContactDataRow row) {
    this.nr_contacts_marked += (row.selector_button.active)? 1 : -1;

    // User selected a first checkbox: enter selection mode
    if (row.selector_button.active && this.nr_contacts_marked == 1)
      this.state = UiState.SELECTING;

    contacts_marked (this.nr_contacts_marked);
  }

  private void contact_removed_cb (Store store, Individual i) {
    var row = find_row_for_contact (i);
    if (row != null)
      row.destroy ();
  }

  private void on_row_activated (Gtk.ListBox listbox, Gtk.ListBoxRow row) {
    if (!this.got_long_press) {
      unowned var data = row as ContactDataRow;
      if (data != null && this.state == UiState.SELECTING)
        data.selector_button.active = !data.selector_button.active;
    } else {
      this.got_long_press = false;
    }
  }

  private void on_row_selected (Gtk.ListBox listbox, Gtk.ListBoxRow? row) {
    if (this.state != UiState.SELECTING) {
      unowned var data = (ContactDataRow?) row;
      unowned var individual = data != null? data.individual : null;
      selection_changed (individual);
#if HAVE_TELEPATHY
      if (individual != null)
        Contacts.Utils.fetch_contact_info (individual);
#endif
    }
  }

  private bool filter_row (Gtk.ListBoxRow row) {
    unowned var individual = ((ContactDataRow) row).individual;
    return this.filter_query.is_match (individual) > 0;
  }

  public void select_contact (Individual? individual) {
    if (individual == null) {
      /* deselect */
      this.listbox.select_row (null);
      return;
    }

    unowned var row = find_row_for_contact (individual);
    this.listbox.select_row (row);
    scroll_to_contact (row);
  }

  private void load_visible_avatars () {
    // FIXME: use the vadjustment to load only the avatars of the visible rows
  }

  public void scroll_to_contact (Gtk.ListBoxRow? row = null) {
    unowned ContactDataRow? selected_row = null;
    if (row == null)
      selected_row = (ContactDataRow?) this.listbox.get_selected_row ();
    else
      selected_row = (ContactDataRow) row;

    GLib.Timeout.add (100, () => {
      if (selected_row != null)
        selected_row.grab_focus ();
      return GLib.Source.REMOVE;
    });
  }

  public void set_contact_visible (Individual? individual, bool visible) {
    if (individual != null) {
      find_row_for_contact (individual).visible = visible;
    }
  }

  private unowned ContactDataRow? find_row_for_contact (Individual individual) {
    for (int i = 0; true; i++) {
      unowned var row = (ContactDataRow) this.listbox.get_row_at_index (i);
      if (row == null)
        break;

      if (row.individual == individual)
        return row;
    }

    return null;
  }

  public Gee.LinkedList<Individual> get_marked_contacts () {
    var cs = new Gee.LinkedList<Individual> ();

    for (int i = 0; true; i++) {
      unowned var row = (ContactDataRow) this.listbox.get_row_at_index (i);
      if (row == null)
        break;

      if (row.selector_button.active)
        cs.add (row.individual);
    }

    return cs;
  }

  public Gee.LinkedList<Individual> get_marked_contacts_and_hide () {
    var cs = new Gee.LinkedList<Individual> ();

    for (int i = 0; true; i++) {
      unowned var row = (ContactDataRow) this.listbox.get_row_at_index (i);
      if (row == null)
        break;

      if (row.selector_button.active) {
        row.visible = false;
        cs.add (row.individual);
      }
    }
    return cs;
  }

  private void on_right_click (Gtk.GestureClick gesture, int n_press, double x, double y) {
    unowned var row = (ContactDataRow) this.listbox.get_row_at_y ((int) Math.round (y));
    if (row != null) {
      row.selector_button.active = this.state != UiState.SELECTING || !row.selector_button.active;
    }
  }

  private void on_long_press (Gtk.GestureLongPress gesture, double x, double y) {
    this.got_long_press = true;
    unowned var row = (ContactDataRow) this.listbox.get_row_at_y ((int) Math.round (y));
    if (row != null) {
      row.selector_button.active = this.state != UiState.SELECTING || !row.selector_button.active;
    }
  }

  // A class for the ListBoxRows
  private class ContactDataRow : Gtk.ListBoxRow {
    private const int LIST_AVATAR_SIZE = 48;

    public unowned Individual individual;
    private unowned Gtk.Label label;
    private unowned Avatar avatar;
    public unowned Gtk.CheckButton selector_button;

    public ContactDataRow (Individual i) {
      this.individual = i;
      this.individual.notify.connect (on_contact_changed);

      add_css_class ("contact-data-row");

      var box = new Gtk.Box (HORIZONTAL, 12);
      box.margin_top = 6;
      box.margin_bottom = 6;

      var avatar = new Avatar (LIST_AVATAR_SIZE, this.individual);
      box.append (avatar);
      this.avatar = avatar;

      var label = new Gtk.Label (individual.display_name);
      label.ellipsize = Pango.EllipsizeMode.END;
      label.valign = Gtk.Align.CENTER;
      label.halign = Gtk.Align.START;
      // Make sure it doesn't "twitch" when the checkbox becomes visible
      label.xalign = 0;
      box.append (label);
      this.label = label;

      var selector_button = new Gtk.CheckButton ();
      selector_button.visible = false;
      selector_button.valign = Gtk.Align.CENTER;
      selector_button.halign = Gtk.Align.END;
      selector_button.hexpand = true;
      selector_button.add_css_class ("selection-mode");
      // Make sure it doesn't overlap with the scrollbar
      selector_button.margin_end = 12;
      box.append (selector_button);
      this.selector_button = selector_button;

      this.set_child (box);
    }

    private void on_contact_changed (Object obj, ParamSpec pspec) {
      if (pspec.get_name () == "avatar") {
        this.avatar.reload ();
      }
      // Always update the label, since it can depend on a lot of properties
      this.label.set_text (this.individual.display_name);
      changed ();
    }
  }
}
