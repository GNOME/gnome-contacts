/*
 * Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * The ContactListSelectionModel is a custom selection model that basically
 * combines 2 selection models:
 * - the default single selection model
 * - a multi-selection model, for when we go into "selection mode"
 *
 * Providing a custom selection which delegates everything rather than using 2
 * models separately has some advantages:
 * - Switching the model for a GtkListView means that it will reload the whole
 * model, leading to unexpected jumps and performance issues
 * - The selection logic for "selection mode" is slighty different than the one
 * that GtkMultiSelection implements, so we can try to work around that here
 * in select_item() and select_range()
 *
 * If you still want access to a specific selection, you can still fetch them
 * as they are public properties of the instance.
 */
public class Contacts.ContactSelectionModel : Object, GLib.ListModel,
                                              Gtk.SelectionModel, Gtk.SectionModel  {

  // The UI state that will decide to delegate to which selection model
  // We expect that this gets synchronized with the rest of the ui state
  public UiState state {
    get { return this._state; }
    set {
      if (this._state == value)
        return;

      this._state = value;
      notify_property ("state");
      if (get_n_items () > 0)
        selection_changed (0, get_n_items ());
    }
  }
  private UiState _state;

  public GLib.ListModel base_model { get; construct set; }

  public Gtk.SingleSelection selected { get; private set; }

  public Gtk.MultiSelection marked { get; private set; }

  construct {
    this.base_model.items_changed.connect (on_base_model_items_changed);

    this.selected = new Gtk.SingleSelection (this.base_model);
    this.selected.can_unselect = true;
    this.selected.autoselect = false;
    this.selected.selection_changed.connect (on_selected_selection_changed);

    this.marked = new Gtk.MultiSelection (this.base_model);
    this.marked.selection_changed.connect (on_marked_selection_changed);
  }

  public ContactSelectionModel (GLib.ListModel base_model) {
    Object (base_model: base_model);
  }

  private void on_base_model_items_changed (ListModel base_model,
                                            uint pos, uint removed, uint added) {
    items_changed (pos, removed, added);
  }

  private void on_selected_selection_changed (Gtk.SelectionModel selected,
                                              uint position,
                                              uint n_changed) {
    if (!use_marked_model ())
      selection_changed (position, n_changed);
  }

  private void on_marked_selection_changed (Gtk.SelectionModel marked,
                                            uint position,
                                            uint n_changed) {
    if (use_marked_model ())
      selection_changed (position, n_changed);
  }

  public unowned Individual? get_selected_individual () {
    return (Individual?) this.selected.selected_item;
  }

  private bool use_marked_model () {
    return this.state == UiState.SELECTING;
  }

  // GLib.ListModel implementation

  public Object? get_item (uint i) {
    return this.base_model.get_item (i);
  }

  public uint get_n_items () {
    return this.base_model.get_n_items ();
  }

  public GLib.Type get_item_type () {
    return typeof (Individual);
  }

  // Gtk.SelectionModel implementation

  public Gtk.Bitset get_selection_in_range (uint position, uint n_items) {
    if (use_marked_model ())
      return this.marked.get_selection_in_range (position, n_items);
    return this.selected.get_selection_in_range (position, n_items);
  }

  public bool is_selected (uint position) {
    if (use_marked_model ())
      return this.marked.is_selected (position);
    return this.selected.is_selected (position);
  }

  public bool select_all () {
    if (use_marked_model ())
      return this.marked.select_all ();
    return this.selected.select_all ();
  }

  public bool select_item (uint position, bool unselect_rest) {
    if (use_marked_model ()) {
      if (this.marked.is_selected (position))
        return this.marked.unselect_item (position);
      return this.marked.select_item (position, false);
    }
    return this.selected.select_item (position, unselect_rest);
  }

  public bool select_range (uint position, uint n_items, bool unselect_rest) {
    if (use_marked_model ())
      return this.marked.select_range (position, n_items, false);
    return this.selected.select_range (position, n_items, unselect_rest);
  }

  public bool set_selection (Gtk.Bitset selected, Gtk.Bitset mask) {
    if (use_marked_model ())
      return this.marked.set_selection (selected, mask);
    return this.selected.set_selection (selected, mask);
  }

  public bool unselect_all () {
    if (use_marked_model ())
      return this.marked.unselect_all ();
    return this.selected.unselect_all ();
  }

  public bool unselect_item (uint position) {
    if (use_marked_model ())
      return this.marked.unselect_item (position);
    return this.selected.unselect_item (position);
  }

  public bool unselect_range (uint position, uint n_items) {
    if (use_marked_model ())
      return this.marked.unselect_range (position, n_items);
    return this.selected.unselect_range (position, n_items);
  }

  // Gtk.SectionModel implementation

  public void get_section (uint position, out uint start, out uint end)
      requires(this.base_model is Gtk.SectionModel) {
    unowned var section_model = (Gtk.SectionModel) this.base_model;
    section_model.get_section (position, out start, out end);
  }
}
