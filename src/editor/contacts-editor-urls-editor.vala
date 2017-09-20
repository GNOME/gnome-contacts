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

using Folks;
using Gee;
using Gtk;

public class Contacts.Editor.UrlsEditor : CompositeEditor<UrlDetails, UrlFieldDetails> {

  public override string persona_property {
    get { return "urls"; }
  }

  public UrlsEditor (UrlDetails? details = null) {
    if (details != null) {
      /* var url_fields = Contact.sort_fields<UrlFieldDetails>(details.urls); */
      /* foreach (var url_field_detail in url_fields) */
      foreach (var url_field_detail in details.urls)
        this.child_editors.add (new UrlEditor (this, url_field_detail));
    } else {
      // No urls were passed on => make a single blank editor
      this.child_editors.add (new UrlEditor (this));
    }
  }

  public override async void save (UrlDetails url_details) throws PropertyError {
    yield url_details.change_urls (aggregate_children ());
  }

  public class UrlEditor : CompositeEditorChild<UrlFieldDetails> {
    private Label label;
    private Entry url_entry;
    private Button delete_button;

    public UrlEditor (UrlsEditor parent, UrlFieldDetails? details = null) {
      this.label = parent.create_label (_("Website"));
      this.url_entry = parent.create_entry ((details != null)? details.value : null);
      this.delete_button = parent.create_delete_button ();
    }

    public override int attach_to_grid (Grid container_grid, int row) {
      container_grid.attach (this.label, 0, row);
      container_grid.attach (this.url_entry, 1, row);
      container_grid.attach (this.delete_button, 2, row);

      return 1;
    }

    public override UrlFieldDetails create_details () {
      // XXX parameters
      return new UrlFieldDetails (this.url_entry.text, null);
    }
  }
}
