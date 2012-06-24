/*
 * This code is from evolution with this license:
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with the program; if not, see <http://www.gnu.org/licenses/>
 *
 */

#include "config.h"
#include <libebook/libebook.h>
#include <glib/gi18n-lib.h>

ESourceRegistry *eds_source_registry = NULL;

void contacts_ensure_eds_accounts (void)
{
  GError *error = NULL;

  /* XXX This blocks while connecting to the D-Bus service.
   *     Maybe it should be created in the Contacts class
   *     and passed in as needed? */

  eds_source_registry = e_source_registry_new_sync (NULL, &error);

  /* If this fails it's game over. */
  if (error != NULL)
    g_error ("%s: %s", G_STRFUNC, error->message);
}

gboolean contacts_has_goa_account (void)
{
  GList *list, *link;
  gboolean has_goa_contacts = FALSE;

  list = e_source_registry_list_sources (eds_source_registry, E_SOURCE_EXTENSION_GOA);

  for (link = list; link != NULL; link = g_list_next (link)) {
    ESource *source = E_SOURCE (link->data);
    ESourceCollection *extension;

    /* Ignore disabled accounts. */
    if (!e_source_get_enabled (source))
      continue;

    /* All ESources with a [GNOME Online Accounts] extension
     * should also have a [Collection] extension.  Verify it. */
    if (!e_source_has_extension (source, E_SOURCE_EXTENSION_COLLECTION))
      continue;

    extension = e_source_get_extension (source, E_SOURCE_EXTENSION_COLLECTION);

    /* This corresponds to the Contacts ON/OFF switch in GOA. */
    if (e_source_collection_get_contacts_enabled (extension)) {
      has_goa_contacts = TRUE;
      break;
    }
  }

  g_list_free_full (list, (GDestroyNotify) g_object_unref);

  return has_goa_contacts;
}

gboolean
contacts_esource_uid_is_google (const char *uid)
{
  ESource *source;
  gboolean uid_is_google = FALSE;

  source = e_source_registry_ref_source (eds_source_registry, uid);
  if (source == NULL)
    return FALSE;

  /* Make sure it's really an address book. */
  if (e_source_has_extension (source, E_SOURCE_EXTENSION_ADDRESS_BOOK)) {
    ESourceBackend *extension;
    const gchar *backend_name;

    extension = e_source_get_extension (source, E_SOURCE_EXTENSION_ADDRESS_BOOK);
    backend_name = e_source_backend_get_backend_name (extension);

    uid_is_google = (g_strcmp0 (backend_name, "google") == 0);
  }

  g_object_unref (source);

  return uid_is_google;
}

const char *
contacts_lookup_esource_name_by_uid (const char *uid)
{
  ESource *source;
  ESource *builtin_address_book;
  const gchar *display_name;

  source = e_source_registry_ref_source (eds_source_registry, uid);
  if (source == NULL)
    return NULL;

  builtin_address_book = e_source_registry_ref_builtin_address_book (eds_source_registry);

  if (e_source_equal (source, builtin_address_book))
    display_name = _("Local Address Book");

  else if (contacts_esource_uid_is_google (uid))
    display_name = _("Google");

  else
    display_name = e_source_get_display_name (source);

  g_object_unref (builtin_address_book);
  g_object_unref (source);

  return display_name;
}

const char *
contacts_lookup_esource_name_by_uid_for_contact (const char *uid)
{
  ESource *source;
  ESource *builtin_address_book;
  const gchar *display_name;

  source = e_source_registry_ref_source (eds_source_registry, uid);
  if (source == NULL)
    return NULL;

  builtin_address_book = e_source_registry_ref_builtin_address_book (eds_source_registry);

  if (e_source_equal (source, builtin_address_book))
    return _("Local Contact");

  else if (contacts_esource_uid_is_google (uid))
    display_name = _("Google");

  else
    display_name = e_source_get_display_name (source);

  g_object_unref (builtin_address_book);
  g_object_unref (source);

  return display_name;
}
