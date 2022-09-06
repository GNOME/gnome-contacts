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
 * A {@link Chunk} that represents the freeform notes attached to a contact
 * (similar to {@link Folks.NoteDetails}}. Each element is a {@link Note}.
 */
public class Contacts.NotesChunk : BinChunk {

  public override string property_name { get { return "notes"; } }

  construct {
    if (persona != null) {
      return_if_fail (persona is NoteDetails);
      unowned var note_details = (NoteDetails) persona;

      foreach (var note_field in note_details.notes) {
        var note = new Note.from_field_details (note_field);
        add_child (note);
      }
    }

    finish_initialization ();
  }

  protected override BinChunkChild create_empty_child () {
    return new Note ();
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is PhoneDetails) {
    var afds = (Gee.Set<NoteFieldDetails>) get_abstract_field_details ();
    yield ((NoteDetails) this.persona).change_notes (afds);
  }
}

public class Contacts.Note : BinChunkChild {

  public string text {
    get { return this._text; }
    set { change_string_prop ("text", ref this._text, value); }
  }
  private string _text = "";

  public override bool is_empty {
    get { return this.text.strip () == ""; }
  }

  public override string icon_name {
    get { return "note-symbolic"; }
  }

  public Note () {
    this.parameters = new Gee.HashMultiMap<string, string> ();
    this.parameters["type"] = "PERSONAL";
  }

  public Note.from_field_details (NoteFieldDetails note_field) {
    this.text = note_field.value;
    this.parameters = note_field.parameters;
  }

  protected override int compare_internal (BinChunkChild other)
      requires (other is Note) {
    return strcmp (this.text, ((Note) other).text);
  }

  public override AbstractFieldDetails? create_afd () {
    if (this.is_empty)
      return null;

    return new NoteFieldDetails (this.text, this.parameters);
  }

  public override BinChunkChild copy () {
    var note = new Note ();
    note.text = this.text;
    copy_parameters (note);
    return note;
  }

  protected override Variant? to_gvariant_internal () {
    return new Variant ("(sv)", this.text, parameters_to_gvariant ());
  }

  public override void apply_gvariant (Variant variant)
      requires (variant.get_type ().equal (new VariantType ("(sv)"))) {

    string note;
    Variant params_variant;
    variant.get ("(sv)", out note, out params_variant);

    this.text = note;
    apply_gvariant_parameters (params_variant);
  }
}
