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
 * Provides a convenient interface to deal with Contacts' settings.
 *
 * When editing this, make sure you keep it in sync with the schema file!
 */
public class Contacts.Settings : GLib.Settings {

  public bool did_initial_setup {
    get { return get_boolean ("did-initial-setup"); }
    set { set_boolean ("did-initial-setup", value); }
  }

  public bool sort_on_surname {
    get { return get_boolean ("sort-on-surname"); }
    set { set_boolean ("sort-on-surname", value); }
  }

  // Window state
  public int window_width {
    get { return get_int ("window-width"); }
    set { set_int ("window-width", value); }
  }
  public int window_height {
    get { return get_int ("window-height"); }
    set { set_int ("window-height", value); }
  }
  public bool window_maximized {
    get { return get_boolean ("window-maximized"); }
    set { set_boolean ("window-maximized", value); }
  }
  public bool window_fullscreen {
    get { return get_boolean ("window-fullscreen"); }
    set { set_boolean ("window-fullscreen", value); }
  }

  public Settings (App app) {
    Object (schema_id: "org.gnome.Contacts");
  }
}
