/*
 * Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-import-dialog.ui")]
public class Contacts.ImportDialog : Adw.Dialog {

  [GtkChild]
  private unowned Adw.PreferencesPage page;

  public ListModel files { get; construct set; }
  private GLib.ListStore parsed_results;
  private Gtk.FlattenListModel parsed_list;

  public Store contacts_store { get; construct set; }

  construct {
    this.parsed_results = new GLib.ListStore (typeof(ListModel));
    this.parsed_list = new Gtk.FlattenListModel (this.parsed_results);

    this.parsed_list.items_changed.connect (on_parsed_list_items_changed);
    on_parsed_list_items_changed (this.parsed_list, 0, 0, 0);

    var n_files = this.files.get_n_items ();

    for (uint i = 0; i < n_files; i++) {
      var file = (File) this.files.get_item (i);
      handle_file.begin (file, n_files > 1);
    }
  }

  static construct {
    install_action ("import", null, (Gtk.WidgetActionActivateFunc) action_import);
  }

  public ImportDialog (Store contacts_store,
                       ListModel files) {
    Object (contacts_store: contacts_store, files: files);
  }

  private async void handle_file (File file, bool show_header) {
    // Show a section per file in the dialog
    var group = new Adw.PreferencesGroup ();
    this.page.add (group);

    // Get the file's display name
    FileInfo file_info;
    unowned string file_name;
    try {
      file_info = file.query_info (FileAttribute.STANDARD_DISPLAY_NAME,
                                   FileQueryInfoFlags.NONE);
      file_name = file_info.get_display_name ();
    } catch (GLib.Error err) {
      set_error_label (group,
                       _("An error occurred reading the selected file"));
      return;
    }

    if (show_header)
      group.title = file_name;

    // Now, parse the data and show a loading spinner while busy
    var spinner = new Adw.Spinner ();
    group.add (spinner);

    GLib.ListModel parsed;
    uint n_parsed = 0;
    try {
      var parse_op = new Io.ParseOperation (file);
      yield parse_op.execute ();
      debug ("Successfully parsed a contact");
      parsed = parse_op.parsed;
      n_parsed = parsed.get_n_items ();
      this.parsed_results.append (parsed);
      group.remove (spinner);
    } catch (GLib.Error err) {
      warning ("Couldn't parse file: %s", err.message);
      set_error_label (group,
                       _("An error occurred reading the file '%s'".printf (file_name)));
      group.remove (spinner);
      return;
    }

    if (n_parsed == 0) {
      set_error_label (group,
                       _("The imported file does not seem to contain any contacts"));
      return;
    }

    if (show_header) {
      group.description = ngettext ("Found %u contact",
                                    "Found %u contacts",
                                    n_parsed).printf (n_parsed);
    }

    for (uint i = 0; i < n_parsed; i++) {
      var contact = (Contact) parsed.get_item (i);
      var row = new Adw.ActionRow ();
      row.title = contact.display_name;
      group.add (row);
    }
  }

  private void set_error_label (Adw.PreferencesGroup group, string error) {
    var label = new Gtk.Label (error);
    label.add_css_class ("error");
    group.add (label);
  }

  private void on_parsed_list_items_changed (ListModel parsed_list,
                                             uint position,
                                             uint removed,
                                             uint added) {
    uint n_contacts = this.parsed_list.get_n_items ();

    // Disable the import button if we don't have anything to import
    action_set_enabled ("import", n_contacts > 0);

    if (n_contacts == 0) {
      this.page.description = _("Can't import: no contacts found");
      return;
    }

    this.page.description =
        ngettext ("By continuing, you will import %u contact",
                  "By continuing, you will import %u contacts",
                  n_contacts).printf (n_contacts);
  }

  private void action_import (string action_name, Variant? param) {
    import.begin ((obj, res) => {
      import.end (res);

      // Close the dialog when done importing
      close ();
    });
  }

  private async void import () {
    try {
      var import_op = new ImportOperation (this.contacts_store, this.parsed_list);
      yield import_op.execute ();
      debug ("Successfully imported contacts");
    } catch (GLib.Error err) {
      warning ("Couldn't import contacts: %s", err.message);
    }
  }
}
