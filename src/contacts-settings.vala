/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
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

/**
 * Provides a convenient interface to deal with the settings.
 */
public class Contacts.Settings {
  private GLib.Settings settings;

  public bool did_initial_setup {
    get { return settings.get_boolean ("did-initial-setup"); }
    set { settings.set_boolean ("did-initial-setup", value); }
  }

  public Settings (App app) {
    this.settings = new GLib.Settings (app.application_id);
  }
}
