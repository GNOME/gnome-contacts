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
