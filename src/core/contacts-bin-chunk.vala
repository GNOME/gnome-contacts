/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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
 * A {@link Chunk} that aggregates multiple values associated to a property
 * (for example, a chunk for phone numbers, or email addresses). These values
 * are represented as {@link BinChunkChild}ren, which BinChunk exposes through
 * the {@link GLib.ListModel} interface.
 *
 * One important property of BinkChunk is that it makes sure at least one empty
 * child exists. This allows us to expose an immutable interface, while being
 * able to synchronize with our UI (which expects this kind of behavior)
 */
public abstract class Contacts.BinChunk : Chunk, GLib.ListModel {

  private GenericArray<BinChunkChild> elements = new GenericArray<BinChunkChild> ();

  public override bool is_empty {
    get {
      if (this.elements.length == 0)
        return true;
      foreach (var chunk_element in this.elements) {
        if (!chunk_element.is_empty)
          return false;
      }
      return true;
    }
  }

  /**
   * Should be called by subclasses when they add a child.
   *
   * It will make sure to add the child in the appropriate position and that
   * the emptines check is appropriately applied.
   */
  protected void add_child (BinChunkChild child) {
    if (child.is_empty && has_empty_child ())
      return;

    child.notify["is-empty"].connect ((obj, pspec) => {
      debug ("Child 'is-empty' changed, doing emptiness check");
      emptiness_check ();
    });

    // Add in a sorted manner
    int i = 0;
    while (i < this.elements.length) {
      if (child.compare (this.elements[i]) < 0)
        break;
      i++;
    }
    this.elements.insert (i, child);
    items_changed (i, 0, 1);
  }

  /**
   * Subclasses should implement this to create an empty child (which will be
   * used for the emptiness check).
   */
  protected abstract BinChunkChild create_empty_child ();

  // A method to check if we have at least one empty row
  // if we don't, it adds an empty child
  protected void emptiness_check () {
    if (has_empty_child ())
      return;

    // We only have non-empty rows, add one
    var child = create_empty_child ();
    add_child (child);
  }

  private bool has_empty_child () {
    for (uint i = 0; i < this.elements.length; i++) {
      if (this.elements[i].is_empty)
        return true;
    }
    return false;
  }

  public override Value? to_value () {
    var afds = new Gee.HashSet<AbstractFieldDetails> ();
    for (uint i = 0; i < this.elements.length; i++) {
      var afd = this.elements[i].create_afd ();
      if (afd != null)
        afds.add (afd);
    }
    return (afds.size != 0)? afds : null;
  }

  /** A helper function to collect the AbstractFieldDetails of the children */
  protected Gee.Set<AbstractFieldDetails> get_abstract_field_details ()
      requires (this.persona != null) {
    var afds = new Gee.HashSet<AbstractFieldDetails> ();
    for (uint i = 0; i < this.elements.length; i++) {
      var afd = this.elements[i].create_afd ();
      if (afd != null)
        afds.add (afd);
    }

    return afds;
  }

  // ListModel implementation

  public uint n_items { get { return this.elements.length; } }

  public GLib.Type item_type { get { return typeof (BinChunkChild); } }

  public Object? get_item (uint i) {
    if (i > this.elements.length)
      return null;
    return (Object) this.elements[i];
  }

  public uint get_n_items () {
    return this.elements.length;
  }

  public GLib.Type get_item_type () {
    return typeof (BinChunkChild);
  }
}

/**
 * A child of a {@link BinChunk}
 */
public abstract class Contacts.BinChunkChild : GLib.Object {

  public Gee.MultiMap<string, string> parameters { get; set; }

  /**
   * Whether this BinChunkChild is empty. You can use the notify signal to
   * listen for changes.
   */
  public abstract bool is_empty { get; }

  /**
   * The icon name that best represents this BinChunkChild
   */
  public abstract string icon_name { get; }

  /**
   * Creates an AbstractFieldDetails from the contents of this child
   *
   * If the contents are invalid (or empty), it returns null.
   */
  public abstract AbstractFieldDetails? create_afd ();

  // A helper to change a string field with the proper propery notifies
  protected void change_string_prop (string prop_name,
                                     ref string old_value,
                                     string new_value) {
    if (new_value == old_value)
      return;

    bool notify_empty = ((new_value.strip () == "") != (old_value.strip () == ""));
    // Don't strip value when setting the old one, since we don't want to
    // prevent users from entering a space or a newline :D
    old_value = new_value;
    notify_property (prop_name);
    if (notify_empty)
      notify_property ("is-empty");
  }

  /**
   * Compares 2 children in an intuitive manner, so that preferred children go
   * first and empty children are last
   */
  public int compare (BinChunkChild other) {
    // Fields with a PREF hint always go first (see vCard PREF attribute)
    var has_pref = has_pref_marker ();
    if (has_pref != other.has_pref_marker ())
      return has_pref? -1 : 1;

    // Empty fields go last
    var empty = this.is_empty;
    if (empty != other.is_empty)
      return empty? 1 : -1;

    // FIXME: maybe also compare the types? (e.g. put HOME before WORK)
    return 0;
  }

  /**
   * Returns whether this child is marked as the "preferred" child, similar to
   * the vCard PREF attribute
   */
  public bool has_pref_marker () {
    var evolution_pref = this.parameters["x-evolution-ui-slot"];
    if (evolution_pref != null && ("1" in evolution_pref))
      return true;

    foreach (var param in this.parameters["type"]) {
      if (param.ascii_casecmp ("PREF") == 0)
        return true;
    }
    return false;
  }
}
