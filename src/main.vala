/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

using Gtk;
using Contacts;


private static string individual_id = null;
private static string email_address = null;
private static const OptionEntry[] options = {
    { "individual", 'i', 0, OptionArg.STRING, ref individual_id,
      N_("Show contact with this individual id"), null },
    { "email", 'e', 0, OptionArg.STRING, ref email_address,
      N_("Show contact with this email address"), null },
    { null }
  };

public static int
main (string[] args) {
  Notify.init (_("Contacts"));
  Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
  Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
  Intl.textdomain (Config.GETTEXT_PACKAGE);

  try {
    Gtk.init_with_args (ref args, "— contact management", options, Config.GETTEXT_PACKAGE);
  } catch (Error e) {
    printerr ("Unable to initialize: %s\n", e.message);
    return 1;
  }

  try {
    var provider = new CssProvider ();
    provider.load_from_path (Config.PKGDATADIR + "/" + "gnome-contacts.css");
    StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider,
					  STYLE_PROVIDER_PRIORITY_APPLICATION);
  } catch {
  }

  var app = new App ();
  if (individual_id != null)
    app.show_individual (individual_id);
  if (email_address != null)
    app.show_by_email (email_address);

  // We delay the initial show a tiny bit so most contacts are loaded when we show
  Timeout.add (100, () => {
      app.window.show ();
      return false;
    });

  Gtk.main ();

  return 0;
}
