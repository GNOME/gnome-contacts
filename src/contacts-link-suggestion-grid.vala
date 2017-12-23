/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * This program is distributed in the hope that it will be useful,
 *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Folks;
using Gee;

/**
 * The LinkSuggestionGrid is show at the bottom of the ContactPane.
 * It offers the user the sugugestion of linking the currently shown contact
 * and another (hopefully) similar contact.
 */
public class Contacts.LinkSuggestionGrid : Grid {

  public signal void suggestion_accepted ();
  public signal void suggestion_rejected ();

  public LinkSuggestionGrid (Contact contact) {
    this.valign = Align.END;

    get_style_context ().add_class ("contacts-suggestion");
    set_redraw_on_allocate (true);

    var image_frame = new ContactFrame (Contact.SMALL_AVATAR_SIZE);
    image_frame.hexpand = false;
    image_frame.margin = 24;
    image_frame.margin_end = 12;
    contact.keep_widget_uptodate (image_frame,  (w) => {
        (w as ContactFrame).set_image (contact.individual, contact);
      });

    attach (image_frame, 0, 0);

    var label = new Label ("");
    if (contact.is_main)
      label.set_markup (Markup.printf_escaped (_("Does %s from %s belong here?"), contact.display_name, contact.format_persona_stores ()));
    else
      label.set_markup (Markup.printf_escaped (_("Do these details belong to %s?"), contact.display_name));
    label.valign = Align.START;
    label.halign = Align.START;
    label.width_chars = 20;
    label.wrap = true;
    label.wrap_mode = Pango.WrapMode.WORD_CHAR;
    label.hexpand = true;
    label.margin_top = 24;
    label.margin_bottom = 24;
    attach (label, 1, 0);

    var bbox = new ButtonBox (Orientation.HORIZONTAL);
    var yes = new Button.with_label (_("Yes"));
    var no = new Button.with_label (_("No"));

    yes.clicked.connect ( () => suggestion_accepted ());
    no.clicked.connect ( () => suggestion_rejected ());

    bbox.add (yes);
    bbox.add (no);
    bbox.set_spacing (8);
    bbox.set_halign (Align.END);
    bbox.set_hexpand (true);
    bbox.margin = 24;
    bbox.margin_start = 12;
    attach (bbox, 2, 0);
    show_all ();
  }
}
