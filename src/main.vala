/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Contacts;

public static int
main (string[] args) {
  Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
  Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
  Intl.textdomain (Config.GETTEXT_PACKAGE);

  Gst.init (ref args);

  var app = new App ();
  app.run (args);
  app = null;

  return 0;
}
