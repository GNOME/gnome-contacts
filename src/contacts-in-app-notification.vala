/*
 * Copyright (C) 2017 Niels De Graef <nielsdegraef@gmail.com>
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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-in-app-notification.ui")]
public class Contacts.InAppNotification : Gtk.Revealer {
  // Close the in-app notification after 5 seconds by default.
  private const uint DEFAULT_KEEPALIVE = 5;

  [GtkChild]
  private Gtk.Grid grid;

  [GtkChild]
  private Gtk.Label label;
  public Gtk.Label message_label {
    get { return this.label; }
  }

  /**
   * Fired when the notification is completely dismissed (i.e. gone).
   */
  public signal void dismissed ();

  /**
   * Creates an in-app notification with the given message, and an accompanying button if not null.
   */
  public InAppNotification (string message, Gtk.Button? button = null) {
    this.label.label = message;

    if (button != null) {
      button.valign = Gtk.Align.CENTER;
      this.grid.attach (button, 1, 0);
      button.show();
    }

    this.notify["child-revealed"].connect (on_child_revealed_changed);
  }

  public new void show () {
    base.show ();
    this.reveal_child = true;

    Timeout.add_seconds (DEFAULT_KEEPALIVE, () => {
        dismiss ();
        return false;
      });
  }

  public void dismiss () {
    this.reveal_child = false;
  }

  private void on_child_revealed_changed (Object o, ParamSpec p) {
    if (!this.child_revealed) {
      dismissed ();
      destroy ();
    }
  }

  [GtkCallback]
  private void on_close_button_clicked(Gtk.Button close_button) {
    dismiss();
  }
}
