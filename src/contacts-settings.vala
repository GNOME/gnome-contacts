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
public class Contacts.Settings : GLib.Settings {

  private const string DID_INITIAL_SETUP_KEY = "did-initial-setup";
  private const string SORT_ON_SURNAME_KEY = "sort-on-surname";
  public const string WINDOW_WIDTH_KEY = "window-width";
  public const string WINDOW_HEIGHT_KEY = "window-height";
  public const string WINDOW_MAXIMIZED_KEY = "window-maximized";

  public bool did_initial_setup {
    get { return get_boolean (DID_INITIAL_SETUP_KEY); }
    set { set_boolean (DID_INITIAL_SETUP_KEY, value); }
  }

  public bool sort_on_surname {
    get { return get_boolean (SORT_ON_SURNAME_KEY); }
    set { set_boolean (SORT_ON_SURNAME_KEY, value); }
  }

  public Settings (App app) {
    Object (schema_id: app.application_id);
  }

  public void bind_default (string key, Object object, string property) {
    bind (key, object, property, GLib.SettingsBindFlags.DEFAULT);
  }
}
