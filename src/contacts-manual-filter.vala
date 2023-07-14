/*
 * Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
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
 * A subclass of {@link Gtk.Filter} which hides a programmatically chosen set
 * of individuals. The main use case here is to temporarily hide individuals
 * that are going to be deleted soon.
 */
public class Contacts.ManualFilter : Gtk.Filter {

  // There's not too much of a point in optimizing this, as the main case is
  // hiding a handful of individuals that are about to deleted
  private GenericArray<unowned Individual> hidden = new GenericArray<unowned Individual> ();

  /**
   * Marks that the given individual should to be hidden
   */
  public void add_individual (Individual individual) {
    this.hidden.add (individual);
    changed (Gtk.FilterChange.MORE_STRICT);
  }

  /**
   * Marks that the given individual should no longer to be hidden
   */
  public void remove_individual (Individual individual)
      requires (this.hidden.find (individual)) {
    this.hidden.remove (individual);
    changed (Gtk.FilterChange.LESS_STRICT);
  }

  public override bool match (Object? item)
      requires (item is Individual) {
    return !this.hidden.find((Individual) item);
  }

  public override Gtk.FilterMatch get_strictness () {
    if (this.hidden.length == 0)
      return Gtk.FilterMatch.ALL;

    return Gtk.FilterMatch.SOME;
  }
}
