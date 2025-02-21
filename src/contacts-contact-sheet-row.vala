/*
 * Copyright (C) 2024 Niels De Graef <nielsdegraef@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * ContactSheetRow is a custom Gtk.ListBoxRow for displaying a field in the
 * ContactSheet widget, similar to when one would use an Adw.ActionRow (or
 * generally a Adw.PreferencesRow).
 */
[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-contact-sheet-row.ui")]
public class Contacts.ContactSheetRow : Adw.PreferencesRow {

  [GtkChild]
  private unowned Gtk.Image image;
  [GtkChild]
  private unowned Gtk.Label title;
  [GtkChild]
  private unowned Gtk.Label subtitle;
  [GtkChild]
  private unowned Gtk.Box suffixes;

  public ContactSheetRow (Chunk chunk, string title, string? subtitle = null) {
    unowned var icon_name = chunk.icon_name;
    if (icon_name != null) {
      this.image.icon_name = icon_name;
      this.image.tooltip_text = chunk.display_name;
    }

    this.title.label = title;

    if (subtitle != null)
      this.subtitle.label = subtitle;
  }

  public void set_title_direction (Gtk.TextDirection direction) {
    this.title.set_direction (direction);
    if (get_default_direction () == Gtk.TextDirection.RTL)
      this.title.xalign = 1.0f;
  }

  public Gtk.Button add_button (string icon) {
    var button = new Gtk.Button.from_icon_name (icon);
    button.valign = Gtk.Align.CENTER;
    button.add_css_class ("flat");
    this.suffixes.append (button);
    this.suffixes.visible = true;
    return button;
  }
}
