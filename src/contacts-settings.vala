/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
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
