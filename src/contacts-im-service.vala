/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

using Folks;

/**
 * ImService is a helper struct that maps a service identifier to the
 * displayable, localised name.
 */
public struct Contacts.ImService {

  unowned string service_name;
  unowned string display_name;

  private const ImService[] data = {
    {         "aim", N_("AOL Instant Messenger")  },
    {    "facebook", N_("Facebook")               },
    {    "gadugadu", N_("Gadu-Gadu")              },
    { "google-talk", N_("Google Talk")            },
    {   "groupwise", N_("Novell Groupwise")       },
    {         "icq", N_("ICQ")                    },
    {         "irc", N_("IRC")                    },
    {      "jabber", N_("Jabber")                 },
    {     "lj-talk", N_("Livejournal")            },
    {  "local-xmpp", N_("Local network")          },
    {         "msn", N_("Windows Live Messenger") },
    {     "myspace", N_("MySpace")                },
    {        "mxit", N_("MXit")                   },
    {     "napster", N_("Napster")                },
    {    "ovi-chat", N_("Ovi Chat")               },
    {          "qq", N_("Tencent QQ")             },
    {    "sametime", N_("IBM Lotus Sametime")     },
    {        "silc", N_("SILC")                   },
    {         "sip", N_("sip")                    },
    {       "skype", N_("Skype")                  },
    {         "tel", N_("Telephony")              },
    {      "trepia", N_("Trepia")                 },
    {       "yahoo", N_("Yahoo! Messenger")       },
    {     "yahoojp", N_("Yahoo! Messenger")       },
    {      "zephyr", N_("Zephyr")                 }
  };

  /**
   * Returns the display name for the given IM service in a nicely presented way.
   */
  public static unowned string get_display_name (string service_name) {
    foreach (unowned ImService d in data)
      if (d.service_name == service_name)
        return dgettext (Config.GETTEXT_PACKAGE, d.display_name);

    return service_name;
  }
}
