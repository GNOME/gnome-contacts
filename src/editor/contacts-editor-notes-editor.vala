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

/**
 * Deals with multiple "Notes"
 */
public class Contacts.Editor.NotesEditor : CompositeEditor<NoteDetails, NoteFieldDetails> {

  public override string persona_property {
    get { return "notes"; }
  }

  public NotesEditor (NoteDetails? details = null) {
    if (details != null) {
      foreach (var note_field_detail in details.notes)
        this.child_editors.add (new NoteEditor (this, note_field_detail));
    } else {
      // No notes were passed on => make a single blank editor
      this.child_editors.add (new NoteEditor (this));
    }
  }

  public override async void save (NoteDetails note_details) throws PropertyError {
    yield note_details.change_notes (aggregate_children ());
  }

  /**
   * Deals with a single "Notes" field.
   */
  public class NoteEditor : CompositeEditorChild<NoteFieldDetails> {
    private Label label;
    private ScrolledWindow note_textview;
    private Button delete_button;

    public NoteEditor (NotesEditor parent, NoteFieldDetails? details = null) {
      this.label = parent.create_label (_("Note"));
      var text = (details != null)? details.value : null;
      this.note_textview = parent.create_textview (text);
      this.delete_button = parent.create_delete_button ();
    }

    public override int attach_to_grid (Grid container_grid, int row) {
      container_grid.attach (this.label, 0, row);
      container_grid.attach (this.note_textview, 1, row);
      container_grid.attach (this.delete_button, 2, row);

      return 1;
    }

    public override NoteFieldDetails create_details () {
      // XXX parameters
      // XXX scrolledwindow
      return new NoteFieldDetails ("test niels", null);
      /* return new NoteFieldDetails (this.note_textview.buffer.text, null); */
    }
  }
}
