/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

/**
 * A list of {@link Contacts.Operation}s.
 */
public class Contacts.OperationList : Object {

  // A helper class to add extra (private) API to operations
  private class OpEntry {
    public Operation operation;
    public Cancellable? cancellable;
    public uint timeout_src;
    public bool finished;

    public OpEntry (Operation operation, Cancellable? cancellable = null) {
      this.operation = operation;
      this.cancellable = cancellable;
      this.timeout_src = 0;
      this.finished = false;
    }

    public bool is_cancelled () {
      return (this.cancellable != null) && this.cancellable.is_cancelled ();
    }
  }

  private GenericArray<OpEntry?> operations = new GenericArray<OpEntry?> ();

  public OperationList () {
  }

  /** Asynchronously executes the given operation */
  public async void execute (Operation operation,
                             Cancellable? cancellable) throws GLib.Error {
    yield execute_with_timeout (operation, 0, cancellable);
  }

  /** Asynchronously executes the given operation after a timeout */
  public async void execute_with_timeout (Operation operation,
                                          uint timeout,
                                          Cancellable? cancellable) throws GLib.Error {
    // Create a new OpEntry to keep track and add it
    var entry = new OpEntry (operation, cancellable);
    this.operations.add (entry);

    // Schedule the callback
    SourceFunc callback = execute_with_timeout.callback;
    if (timeout > 0) {
      entry.timeout_src = Timeout.add_seconds (timeout, (owned) callback);
    } else {
      entry.timeout_src = Idle.add ((owned) callback);
    }

    // Let the main loop take control again, our callback should be scheduled
    // at this point.
    yield;

    yield execute_operation_now (entry);
  }

  /** Cancel the operation with the given UUID */
  public async void cancel_operation (string uuid) throws GLib.Error {
    debug ("Cancelling operation '%s'", uuid);

    unowned var entry = find_by_uuid (uuid);
    if (entry == null || entry.finished) { // FIXME: throw some error
      warning ("Can't cancel operation with uuid '%s': not found", uuid);
      return;
    }

    if (entry.finished) { // FIXME: throw some error
      warning ("Can't cancel operation '%s': already finished",
               entry.operation.description);
      return;
    }

    if (entry.is_cancelled ())
      return; // no-op

    entry.cancellable.cancel ();
  }

  /**
   * Undo the operation with the given UUID
   */
  public async void undo_operation (string uuid) throws GLib.Error {
    debug ("Undoing operation '%s'", uuid);

    unowned var entry = find_by_uuid (uuid);
    if (entry == null) { // FIXME: throw some error
      warning ("Can't undo operation with uuid '%s': not found", uuid);
      return;
    }

    if (!entry.operation.reversable || !entry.finished || entry.is_cancelled ()) {
      warning ("Can't undo operation with uuid '%s'", uuid);
      return;
    }

    yield entry.operation.undo ();
  }

  /**
   * Returns whether there are operations that are still unfinished
   */
  public bool has_pending_operations () {
    return (find_next_todo () != null);
  }

  /**
   * Flushes the current list of operaions. This will execute any operation
   * that was still scheduled for execution.
   */
  public async void flush () throws GLib.Error {
    if (!has_pending_operations ())
      return;

    debug ("Flushing %u operations", this.operations.length);

    unowned var entry = find_next_todo ();
    while (entry != null) {
      debug ("Flushing operation '%s'", entry.operation.description);
      yield execute_operation_now (entry);
      entry = find_next_todo ();
    }

    this.operations.remove_range (0, this.operations.length);
  }

  private unowned OpEntry? find_next_todo () {
    for (uint i = 0; i < operations.length; i++) {
      unowned var entry = operations[i];
      if (!entry.finished && !entry.is_cancelled ())
        return entry;
    }

    return null;
  }

  private unowned OpEntry? find_by_uuid (string uuid) {
    for (uint i = 0; i < operations.length; i++) {
      if (operations[i].operation.uuid == uuid)
        return operations[i];
    }

    return null;
  }

  private async void execute_operation_now (OpEntry? entry) throws GLib.Error {
    // Clear any scheduled callbacks
    entry.timeout_src = 0;

    // Check if it might've been scheduled in the meantime
    if (entry.is_cancelled ()) {
      throw new IOError.CANCELLED ("Operation '%s' was cancelled",
                                   entry.operation.description);
    }

    debug ("Starting execution of operation '%s' (%s)",
           entry.operation.description, entry.operation.uuid);
    yield entry.operation.execute ();
    entry.finished = true;
    debug ("Finished operation '%s' (%s)",
           entry.operation.description, entry.operation.uuid);
  }
}
