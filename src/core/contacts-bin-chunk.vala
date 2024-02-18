/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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

  private BinChunkChild[] original_elements;
  private bool original_elements_set = false;

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

  public override bool dirty {
    get {
      // If we're hitting this, a subclass forgot to set the field
      warn_if_fail (this.original_elements_set);

      var non_empty_count = nr_nonempty_children ();
      if (this.original_elements.length != non_empty_count)
          return true;

      // Since we guarantee ordering by BinChunkChild::compare,
      // we can just check for equality by paired indices (ignoring the empty
      // ones though)
      for (uint i = 0, j = 0; i < this.elements.length; i++, j++) {
        if (this.elements[i].is_empty) {
          j--;
          continue;
        }
        if (this.elements[i].compare (this.original_elements[j]) != 0)
          return true;
      }
      return false;
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

  private uint nr_nonempty_children () {
    uint result = 0;
    for (uint i = 0; i < this.elements.length; i++) {
      if (!this.elements[i].is_empty)
        result++;
    }
    return result;
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

  /**
   * A helper finish the initialization of a BinChunk. It makes sure to set the
   * "original_elements" field (which is used to calculate the "dirty"
   * property) as well as doing an initial emptiness check
   */
  protected void finish_initialization () {
    // Make a deep copy to ensure changes don't propagate to original_elements
    this.original_elements = this.elements.copy ((child) => {
        return child.copy ();
    }).steal ();
    this.original_elements_set = true;

    emptiness_check ();
  }

  // Variant (de)serialization

  public override Variant? to_gvariant () {
    if (this.is_empty)
      return null;

    var builder = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
    for (uint i = 0; i < this.elements.length; i++) {
      var child_variant = this.elements[i].to_gvariant ();
      if (child_variant != null)
        builder.add_value (child_variant);
    }

    return builder.end ();
  }

  public override void apply_gvariant (Variant variant,
                                       bool mark_dirty = true)
      requires (variant.get_type ().is_array ()) {

    var iter = variant.iterator ();
    var child_variant = iter.next_value ();
    while (child_variant != null) {
      var child = create_empty_child ();
      child.apply_gvariant (child_variant);
      add_child (child);

      child_variant = iter.next_value ();
    }
    if (!mark_dirty) {
      finish_initialization ();
    }
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

  public Gee.MultiMap<string, string> parameters {
      get { return this._parameters; }
      set {
        if (value == this._parameters)
          return;

        this._parameters.clear ();
        var iter = value.map_iterator ();
        while (iter.next ())
          this._parameters[iter.get_key ()] = iter.get_value ();
      }
  }
  private Gee.HashMultiMap<string, string> _parameters
      = new Gee.HashMultiMap<string, string> ();

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

  /**
   * Creates a deep copy of this child
   */
  public abstract BinChunkChild copy ();

  // Helper to copy this object's parameters field into that of @copy
  protected void copy_parameters (BinChunkChild copy) {
    copy.parameters.clear ();
    var iter = this.parameters.map_iterator ();
    while (iter.next ())
      copy.parameters[iter.get_key ()] = iter.get_value ();
  }

  /** See Contacts.Chunk.to_gvariant() */
  public Variant? to_gvariant () {
    if (this.is_empty)
      return null;
    return to_gvariant_internal ();
  }

  protected abstract Variant? to_gvariant_internal ();

  // Helper to serialize the parameters field
  protected Variant parameters_to_gvariant () {
    if (this.parameters.size == 0) {
      return new GLib.Variant ("a(ss)", null); // Empty array
    }

    var builder = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
    var iter = this.parameters.map_iterator ();
    while (iter.next ()) {
      string param_name = iter.get_key ();
      string param_value = iter.get_value ();

      builder.add ("(ss)", param_name, param_value);
    }

    return builder.end ();
  }

  public abstract void apply_gvariant (Variant variant);

  protected void apply_gvariant_parameters (Variant parameters)
      requires (parameters.get_type ().equal (new VariantType ("a(ss)"))) {

    var iter = parameters.iterator ();
    string param_name, param_value;
    while (iter.next ("(ss)", out param_name, out param_value)) {
      if (param_name == AbstractFieldDetails.PARAM_TYPE)
        add_parameter (param_name, param_value.down ());
      else
        add_parameter (param_name, param_value);
    }
  }

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
   * Compares 2 children in such a way that unequal children are sorted in an
   * intuitive manner
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
    return compare_internal (other);
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

  /**
   * Should be implemented by subclasses to compare with logic specific to that
   * property. Note that we ideally try to go for a stable sort
   */
  protected abstract int compare_internal (BinChunkChild other);

  // Helper to do a very dumb ordering with this function
  protected int dummy_compare_parameters (BinChunkChild other) {
    // TYPE is a special vcard param, so use that
    var this_types = this.parameters["type"].to_array ();
    var other_types = other.parameters["type"].to_array ();

    // If one type is more specific than the other, use that
    if (this_types.length != other_types.length)
      return other_types.length - this_types.length;

    for (uint i = 0; i < this_types.length; i++) {
      var type_cmp = strcmp (this_types[i], other_types[i]);
      if (type_cmp != 0)
        return type_cmp;
    }

    // If the number of parameters is larger, assume it's more specific
    // so put it up front
    if (this.parameters.size != other.parameters.size)
      return other.parameters.size - this.parameters.size;

    // Go over all parameters and check for any difference in size
    var keys = this.parameters.get_keys ();
    foreach (string key in keys) {
      var this_params = this.parameters[key];
      var other_params = other.parameters[key];

      if (this_params.size != other_params.size)
        return other_params.size - this_params.size;
    }

    return 0;
  }

  public void add_parameter (string param_name, string param_value) {
    this._parameters[param_name] = param_value;
  }
}
