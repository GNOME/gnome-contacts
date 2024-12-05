/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * The ContactList is the widget that diplays the list of contacts
 * ({@link Folks.Individual}s) that the user sees on the left. It is contained
 * by the {@link Contacts.ListPane}, which also provides other functionality,
 * such as an action bar.
 *
 * On top of the list models, we have a {@link Gtk.SelectionModel} which keeps
 * track of the contacts that were selected.
 */
public class Contacts.ContactList : Adw.Bin {

  public Store store { get; construct; }

  public Contacts.ContactSelectionModel selection_model { get; construct; }

  public UiState state { get; set; }

  private unowned Gtk.ListView list_view;

  construct {
    // Build the factory for the items/contacts
    var factory = new Gtk.SignalListItemFactory ();
    factory.setup.connect (on_setup_item);
    factory.bind.connect (on_bind_item);
    factory.unbind.connect (on_unbind_item);
    factory.teardown.connect (on_teardown_item);

    // Build the factory for the headers
    var header_factory = new Gtk.SignalListItemFactory ();
    header_factory.setup.connect (on_create_header);
    header_factory.bind.connect (on_bind_header);

    // Now the listview that will actually show the contact list
    var listview = new Gtk.ListView (this.selection_model, factory);
    listview.header_factory = header_factory;
    listview.tab_behavior = Gtk.ListTabBehavior.ITEM;
    listview.add_css_class ("contact-list");
    listview.add_css_class ("navigation-sidebar");
    this.list_view = listview;

    // Wrap the listview in a scrolled window
    var sw = new Gtk.ScrolledWindow ();
    sw.hscrollbar_policy = Gtk.PolicyType.NEVER;
    sw.child = listview;
    this.child = sw;
  }

  public ContactList (Store store, ContactSelectionModel selection_model) {
    Object (store: store, selection_model: selection_model);
  }

  private void on_setup_item (Object object) {
    unowned var item = (Gtk.ListItem) object;

    // Create the row widget
    var row = new ContactListRow ();
    item.child = row;

    // Update the selection mode on state changes
    row.selection_mode = (this.state == UiState.SELECTING);
    var state_notify_handler = this.notify["state"].connect ((obj, pspec) => {
      row.selection_mode = (this.state == UiState.SELECTING);
    });
    item.set_data<ulong> ("state-notify-handler", state_notify_handler);

    // Bind the GtkItemList "selected" property, we use it for the checkmark
    var sel_binding = item.bind_property ("selected", row, "selected",
                                          BindingFlags.SYNC_CREATE);
    item.set_data<Binding> ("sel-binding", sel_binding);

    // Listen to the toggle-marked signal
    row.toggle_marked.connect ((select) => {
      this.state = UiState.SELECTING;
      if (!select)
        return;

      if (this.selection_model.is_selected (item.position)) {
        this.selection_model.unselect_item (item.position);
      } else {
        this.selection_model.select_item (item.position, false);
      }
    });
  }

  private void on_teardown_item (Object object) {
    unowned var item = (Gtk.ListItem) object;

    // Disconnect all signals from setup-item
    var state_notify_handler = item.steal_data<ulong> ("state-notify-handler");
    disconnect (state_notify_handler);

    var sel_binding = item.steal_data<Binding> ("sel-binding");
    sel_binding.unbind ();
  }

  private void on_bind_item (Object object) {
    unowned var item = (Gtk.ListItem) object;
    unowned var row = (ContactListRow) item.child;
    unowned var individual = (Individual?) item.item;

    row.individual = individual;
  }

  private void on_unbind_item (Object object) {
    unowned var item = (Gtk.ListItem) object;
    unowned var row = (ContactListRow) item.child;

    row.individual = null;
  }

  private void on_create_header (Object object) {
    unowned var header = (Gtk.ListHeader) object;

    var label = new Gtk.Label ("");
    label.halign = Gtk.Align.START;
    label.add_css_class ("heading");
    label.add_css_class ("dim-label");

    header.child = label;
  }

  private void on_bind_header (Object object) {
    unowned var header = (Gtk.ListHeader) object;
    unowned var label = (Gtk.Label) header.child;
    unowned var individual = (Individual) header.item;

    if (individual.is_favourite)
      label.label = _("Favorites");
    else
      label.label = _("All Contacts");
  }

  public void scroll_to_selected () {
    var selected = this.selection_model.selected.selected;
    if (selected != Gtk.INVALID_LIST_POSITION)
        this.list_view.scroll_to (selected, Gtk.ListScrollFlags.NONE, null);
  }

  /** A widget that shows a small summary for a contact */
  private class ContactListRow : Gtk.Box {

    private const int LIST_AVATAR_SIZE = 48;

    private unowned Gtk.Label name_label;
    private unowned Avatar avatar;
    private unowned Gtk.CheckButton selector_button;

    public Individual? individual {
      get { return this._individual; }
      set {
        if (this._individual == value)
          return;

        update_individual (value);
        notify_property ("individual");
      }
    }
    private Individual? _individual = null;

    public bool selection_mode {
      get { return this.selector_button.visible; }
      set { this.selector_button.visible = value; }
    }

    public bool selected {
      get { return this.selector_button.active; }
      set {
        this.ignore_selected = true;
        this.selector_button.active = value;
        this.ignore_selected = false;
      }
    }
    private bool ignore_selected = false;

    public signal void toggle_marked (bool select);

    construct {
      this.orientation = Gtk.Orientation.HORIZONTAL;
      this.spacing = 12;

      add_css_class ("contact-list-row");

      var avatar = new Avatar (LIST_AVATAR_SIZE);
      append (avatar);
      this.avatar = avatar;

      var label = new Gtk.Label ("");
      label.ellipsize = Pango.EllipsizeMode.END;
      label.valign = Gtk.Align.CENTER;
      label.halign = Gtk.Align.START;
      // Make sure it doesn't "twitch" when the checkbox becomes visible
      label.xalign = 0;
      append (label);
      this.name_label = label;

      var selector_button = new Gtk.CheckButton ();
      selector_button.visible = false;
      selector_button.valign = Gtk.Align.CENTER;
      selector_button.halign = Gtk.Align.END;
      selector_button.hexpand = true;
      selector_button.add_css_class ("selection-mode");
      // Make sure it doesn't overlap with the scrollbar
      selector_button.margin_end = 12;
      selector_button.toggled.connect (on_selector_button_toggled);
      append (selector_button);
      this.selector_button = selector_button;

      // Connect events right-click and long-press
      var secondary_click_gesture = new Gtk.GestureClick ();
      secondary_click_gesture.button = Gdk.BUTTON_SECONDARY;
      secondary_click_gesture.pressed.connect (on_right_click);
      add_controller (secondary_click_gesture);

      var long_press_gesture = new Gtk.GestureLongPress ();
      long_press_gesture.pressed.connect (on_long_press);
      add_controller (long_press_gesture);
    }

    private void update_individual (Individual? individual) {
      if (this._individual != null) {
        this._individual.notify["display-name"].disconnect (on_name_notify);
      }
      this._individual = individual;

      if (individual == null) {
        this.name_label.label = "";
        this.avatar.individual = null;
        return;
      }

      this.name_label.label = individual.display_name;
      this._individual.notify["display-name"].connect (on_name_notify);
      this.avatar.individual = individual;
    }

    private void on_name_notify (Object object, ParamSpec pspec) {
      this.name_label.label = this.individual.display_name;
    }

    private void on_right_click (Gtk.GestureClick gesture, int n_press, double x, double y) {
      toggle_marked (true);
    }

    private void on_long_press (Gtk.GestureLongPress gesture, double x, double y) {
      toggle_marked (false);
    }

    private void on_selector_button_toggled (Gtk.CheckButton selector_button) {
      // We have to be careful here: we want to handle the case where a user
      // directly toggles the check button, _but_ once the SelectionModel also
      // marks this row as selected, we'll end up in an infinite loop as that
      // toggles the check button again.
      // Awkwardly work around this by ignoring this signal when set externally
      if (!this.ignore_selected)
        toggle_marked (true);
    }
  }
}
