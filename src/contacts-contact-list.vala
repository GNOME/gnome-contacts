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
 * The ContactList is the widget that diplays the list of contacts
 * ({@link Individual}s) that the user sees on the left. It is contained by the
 * {@link ListPane}, which also provides other functionality, such as an action
 * bar.
 *
 * On top of the list models, we have a {@link Gtk.SelectionModel} which keeps
 * track of the contacts that were selected.
 */
public class Contacts.ContactList : Adw.Bin {

  public Store store { get; construct; }

  public Gtk.MultiSelection marked_contacts { get; construct; }

  public UiState state { get; set; }

  private unowned Gtk.ListBox listbox;

  construct {
    this.add_css_class ("contacts-contact-list");

    // Our selection model for marked contacts (used in selection mode)
    this.marked_contacts.selection_changed.connect (on_marked_contacts_changed);

    var list_box = new Gtk.ListBox ();
    this.listbox = list_box;
    this.listbox.bind_model (this.store.filter_model, create_row_for_item);
    this.listbox.selection_mode = Gtk.SelectionMode.BROWSE;
    this.listbox.set_header_func (update_header);
    this.listbox.add_css_class ("navigation-sidebar");

    this.listbox.row_selected.connect (on_row_selected);
    this.listbox.row_activated.connect (on_row_activated);

    // Connect events right-click and long-press
    var secondary_click_gesture = new Gtk.GestureClick ();
    secondary_click_gesture.button = Gdk.BUTTON_SECONDARY;
    secondary_click_gesture.pressed.connect (on_right_click);
    this.listbox.add_controller (secondary_click_gesture);

    var long_press_gesture = new Gtk.GestureLongPress ();
    long_press_gesture.pressed.connect (on_long_press);
    this.listbox.add_controller (long_press_gesture);

    // Construct our widget tree (just a scrolledwindow + vp with a listbox)
    var sw = new Gtk.ScrolledWindow ();
    sw.hscrollbar_policy = Gtk.PolicyType.NEVER;
    sw.add_css_class ("contact-list-scrolled-window");
    this.child = sw;

    var viewport = new Gtk.Viewport (sw.hadjustment, sw.vadjustment);
    viewport.scroll_to_focus = true;
    viewport.set_child (this.listbox);
    sw.set_child (viewport);
  }

  public ContactList (Store store, Gtk.MultiSelection marked_contacts) {
    Object (store: store, marked_contacts: marked_contacts);
  }

  private Gtk.Widget create_row_for_item (GLib.Object item) {
    unowned var individual = (Individual) item;

    var row = new ContactDataRow (individual, this.marked_contacts);
    this.notify["state"].connect ((obj, pspec) => {
      row.selection_mode = (this.state == UiState.SELECTING);
    });

    return row;
  }

  private void on_marked_contacts_changed (Gtk.SelectionModel marked_contacts,
                                           uint position,
                                           uint n_changed) {
    for (uint i = position; i < position + n_changed; i++) {
      unowned var row = (ContactDataRow) this.listbox.get_row_at_index ((int) i);
      row.marked = marked_contacts.is_selected (i);
    }
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

  private void on_row_activated (Gtk.ListBox listbox, Gtk.ListBoxRow row) {
    if (this.state == UiState.SELECTING) {
      unowned var c_row = (ContactDataRow) row;
      c_row.marked = !c_row.marked;
    }
  }

  private void on_row_selected (Gtk.ListBox listbox, Gtk.ListBoxRow? row) {
    if (this.state != UiState.SELECTING) {
      if (row == null) {
        this.store.selection.unselect_all ();
      } else {
        this.store.selection.select_item (row.get_index (), true);
      }
    }
  }

  public void scroll_to_selected () {
    unowned var row = this.listbox.get_selected_row ();
    if (row == null)
      return;

    GLib.Timeout.add (100, () => {
      row.grab_focus ();
      return GLib.Source.REMOVE;
    });
  }

  public void set_contacts_visible (Gtk.Bitset selection, bool visible) {
    var iter = Gtk.BitsetIter ();
    uint index;
    if (!iter.init_first (selection, out index))
      return;

    do {
      this.listbox.get_row_at_index ((int) index).visible = visible;
    } while (iter.next (out index));
  }

  private void on_right_click (Gtk.GestureClick gesture, int n_press, double x, double y) {
    this.state = UiState.SELECTING;

    unowned var row = this.listbox.get_row_at_y ((int) Math.round (y));
    if (row != null)
      row.activate ();
  }

  private void on_long_press (Gtk.GestureLongPress gesture, double x, double y) {
    this.state = UiState.SELECTING;

    unowned var row = this.listbox.get_row_at_y ((int) Math.round (y));
    if (row != null)
      row.activate ();
  }

  /**
   * A widget that shows a small summary for a contact.
   */
  private class ContactDataRow : Gtk.ListBoxRow {
    private const int LIST_AVATAR_SIZE = 48;

    public Individual individual { get; construct; }

    private unowned Gtk.Label name_label;
    private unowned Avatar avatar;
    public unowned Gtk.CheckButton selector_button;

    public bool selection_mode {
      get { return this.selector_button.visible; }
      set { this.selector_button.visible = value; }
    }

    private unowned Gtk.SelectionModel marked_contacts;
    public bool marked {
      get { return this.marked_contacts.is_selected (get_index ()); }
      set {
        if (value)
          this.marked_contacts.select_item (get_index (), false);
        else
          this.marked_contacts.unselect_item (get_index ());
        notify_property ("marked");
      }
    }

    construct {
      add_css_class ("contact-data-row");

      var box = new Gtk.Box (HORIZONTAL, 12);
      box.margin_top = 6;
      box.margin_bottom = 6;

      var avatar = new Avatar (LIST_AVATAR_SIZE);
      box.append (avatar);
      this.avatar = avatar;

      var label = new Gtk.Label ("");
      label.ellipsize = Pango.EllipsizeMode.END;
      label.valign = Gtk.Align.CENTER;
      label.halign = Gtk.Align.START;
      // Make sure it doesn't "twitch" when the checkbox becomes visible
      label.xalign = 0;
      box.append (label);
      this.name_label = label;

      var selector_button = new Gtk.CheckButton ();
      selector_button.visible = false;
      selector_button.valign = Gtk.Align.CENTER;
      selector_button.halign = Gtk.Align.END;
      selector_button.hexpand = true;
      bind_property ("marked", selector_button, "active", BindingFlags.BIDIRECTIONAL);
      selector_button.add_css_class ("selection-mode");
      // Make sure it doesn't overlap with the scrollbar
      selector_button.margin_end = 12;
      box.append (selector_button);
      this.selector_button = selector_button;

      this.set_child (box);
    }

    public ContactDataRow (Individual individual, Gtk.SelectionModel marked_contacts) {
      Object (individual: individual);

      this.marked_contacts = marked_contacts;
      this.name_label.set_text (individual.display_name);
      this.avatar.individual = individual;
      individual.notify.connect (on_contact_changed);
    }

    private void on_contact_changed (Object obj, ParamSpec pspec) {
      // Always update the label, since it can depend on a lot of properties
      this.name_label.set_text (this.individual.display_name);
      changed ();
    }
  }
}
