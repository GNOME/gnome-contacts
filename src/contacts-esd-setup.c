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
#include <libedataserverui/libedataserverui.h>
#include <glib/gi18n-lib.h>

#define GOA_API_IS_SUBJECT_TO_CHANGE
#include <goa/goa.h>
#include <gtk/gtk.h>

static void
eds_show_source_error (const gchar *where,
		       const gchar *what,
		       ESource *source,
		       const GError *error)
{
  if (!error || g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
    return;

  /* TODO Show the error in UI, somehow */
  g_warning ("%s: %s '%s': %s", where, what, e_source_get_display_name (source), error->message);
}

static void
eds_source_invoke_authenticate_cb (GObject *source_object,
				   GAsyncResult *result,
				   gpointer user_data)
{
  ESource *source = E_SOURCE (source_object);
  GError *error = NULL;

  if (!e_source_invoke_authenticate_finish (source, result, &error) &&
      !g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) {
    eds_show_source_error (G_STRFUNC, "Failed to invoke authenticate", source, error);
  }

  g_clear_error (&error);
}

static void
eds_source_trust_prompt_done_cb (GObject *source_object,
				 GAsyncResult *result,
				 gpointer user_data)
{
  ETrustPromptResponse response = E_TRUST_PROMPT_RESPONSE_UNKNOWN;
  ESource *source = E_SOURCE (source_object);
  GError *error = NULL;

  if (!e_trust_prompt_run_for_source_finish (source, result, &response, &error)) {
    eds_show_source_error (G_STRFUNC, "Failed to prompt for trust for", source, error);
  } else if (response == E_TRUST_PROMPT_RESPONSE_ACCEPT || response == E_TRUST_PROMPT_RESPONSE_ACCEPT_TEMPORARILY) {
    /* Use NULL credentials to reuse those from the last time. */
    e_source_invoke_authenticate (source, NULL, NULL /* cancellable */, eds_source_invoke_authenticate_cb, NULL);
  }

  g_clear_error (&error);
}

static void
eds_source_credentials_required_cb (ESourceRegistry *registry,
				    ESource *source,
				    ESourceCredentialsReason reason,
				    const gchar *certificate_pem,
				    GTlsCertificateFlags certificate_errors,
				    const GError *op_error,
				    ECredentialsPrompter *credentials_prompter)
{
  if (e_credentials_prompter_get_auto_prompt_disabled_for (credentials_prompter, source))
    return;

  if (reason == E_SOURCE_CREDENTIALS_REASON_SSL_FAILED) {
    e_trust_prompt_run_for_source (e_credentials_prompter_get_dialog_parent (credentials_prompter),
	source, certificate_pem, certificate_errors, op_error ? op_error->message : NULL,
	TRUE /* allow_source_save */, NULL /* cancellable */, eds_source_trust_prompt_done_cb, NULL);
  } else if (reason == E_SOURCE_CREDENTIALS_REASON_ERROR && op_error) {
    eds_show_source_error (G_STRFUNC, "Failed to authenticate", source, op_error);
  }
}

ESourceRegistry *eds_source_registry = NULL;
static ECredentialsPrompter *eds_credentials_prompter = NULL;

gboolean contacts_ensure_eds_accounts (void)
{
  ESourceCredentialsProvider *credentials_provider;
  GList *list, *link;
  GError *error = NULL;

  if (eds_source_registry)
    return TRUE;

  /* XXX This blocks while connecting to the D-Bus service.
   *     Maybe it should be created in the Contacts class
   *     and passed in as needed? */

  eds_source_registry = e_source_registry_new_sync (NULL, &error);

  /* If this fails it's game over. */
  if (error != NULL)
    {
      g_error ("%s: %s", G_STRFUNC, error->message);
      return FALSE;
    }

  eds_credentials_prompter = e_credentials_prompter_new (eds_source_registry);

  /* First disable credentials prompt for all but addressbook sources... */
  list = e_source_registry_list_sources (eds_source_registry, NULL);

  for (link = list; link != NULL; link = g_list_next (link)) {
    ESource *source = E_SOURCE (link->data);

    /* Mark for skip also currently disabled sources */
    if (!e_source_has_extension (source, E_SOURCE_EXTENSION_ADDRESS_BOOK))
      e_credentials_prompter_set_auto_prompt_disabled_for (eds_credentials_prompter, source, TRUE);
  }

  g_list_free_full (list, g_object_unref);

  credentials_provider = e_credentials_prompter_get_provider (eds_credentials_prompter);

  /* ...then enable credentials prompt for credential source of the addressbook sources,
     which can be a collection source.  */
  list = e_source_registry_list_sources (eds_source_registry, E_SOURCE_EXTENSION_ADDRESS_BOOK);

  for (link = list; link != NULL; link = g_list_next (link)) {
    ESource *source = E_SOURCE (link->data), *cred_source;

    cred_source = e_source_credentials_provider_ref_credentials_source (credentials_provider, source);
    if (cred_source && !e_source_equal (source, cred_source))
      e_credentials_prompter_set_auto_prompt_disabled_for (eds_credentials_prompter, cred_source, FALSE);
    g_clear_object (&cred_source);
  }

  g_list_free_full (list, g_object_unref);

  /* The eds_credentials_prompter responses to REQUIRED and REJECTED reasons,
     the SSL_FAILED should be handled elsewhere. */
  g_signal_connect (eds_source_registry, "credentials-required",
     G_CALLBACK (eds_source_credentials_required_cb), eds_credentials_prompter);

  e_credentials_prompter_process_awaiting_credentials (eds_credentials_prompter);

  return TRUE;
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

GtkWidget*
contacts_get_icon_for_goa_account (const char* goa_id)
{
  GoaClient *client;
  GoaObject *goa_object;
  GoaAccount *goa_account;
  GError *error;

  const gchar* icon_data;
  GIcon *provider_icon;
  GtkWidget *image_icon;

  error = NULL;
  client = goa_client_new_sync (NULL, &error);
  if (client == NULL)
    {
      g_error_free (error);
      return NULL;
    }

  goa_object = goa_client_lookup_by_id (client, goa_id);
  goa_account = goa_object_get_account (goa_object);

  icon_data = goa_account_get_provider_icon (goa_account);

  error = NULL;
  provider_icon = g_icon_new_for_string (icon_data, &error);
  if (provider_icon == NULL)
    {
      g_debug ("Error obtaining provider_icon");
      g_error_free (error);
    }
  image_icon = gtk_image_new_from_gicon (provider_icon, GTK_ICON_SIZE_DIALOG);

  g_object_unref (goa_account);
  g_object_unref (goa_object);

  g_clear_object (&client);

  return image_icon;
}
