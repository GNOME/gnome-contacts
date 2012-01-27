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
#define GOA_API_IS_SUBJECT_TO_CHANGE
#include <goa/goa.h>
#include <libebook/e-book.h>
#include <libebook/e-book-client.h>
#include <libedataserver/e-url.h>
#include <libedataserver/e-source.h>
#include <libedataserver/e-source-group.h>
#include <libedataserver/e-uid.h>
#include <libedataserver/eds-version.h>
#include <glib/gi18n-lib.h>

char *contacts_eds_local_store = NULL;
static gboolean created_local = FALSE;
static GMainLoop *goa_loop;
static GoaClient *goa_client;
static GHashTable *accounts;
ESourceList *contacts_source_list;
gboolean contacts_avoid_goa_workaround = FALSE;

/* This whole file is a gigantic hack that copies and pastes stuff from
 * evolution to create evolution-data-server addressbooks as needed.
 * Long term we want to move this code out of evolution into a central
 * registry, see:
 * https://mail.gnome.org/archives/evolution-hackers/2011-August/msg00025.html
 * However, to get this going for Gnome 3.2 we're gonna have to do a bad hack.
 */

#define EVOLUTION_GETTEXT_PACKAGE "evolution-3.2"
#define evo_gettext(s) g_dgettext(EVOLUTION_GETTEXT_PACKAGE, (s))

// This was copied from book_shell_backend_ensure_sources

static ESource *
search_known_sources (ESourceList *sources,
                      gboolean (*check_func) (ESource *source,
                                              gpointer user_data),
                      gpointer user_data)
{
	ESource *res = NULL;
	GSList *g;

	g_return_val_if_fail (check_func != NULL, NULL);
	g_return_val_if_fail (sources != NULL, NULL);

	for (g = e_source_list_peek_groups (sources); g; g = g->next) {
		ESourceGroup *group = E_SOURCE_GROUP (g->data);
		GSList *s;

		for (s = e_source_group_peek_sources (group); s; s = s->next) {
			ESource *source = E_SOURCE (s->data);

			if (check_func (source, user_data)) {
				res = g_object_ref (source);
				break;
			}
		}

		if (res)
			break;
	}

	return res;
}

static gboolean
check_default (ESource *source,
	       gpointer data)
{

	if (e_source_get_property (source, "default"))
	  return TRUE;

	return FALSE;
}

static gboolean
check_uri (ESource *source,
           gpointer uri)
{
	const gchar *suri;
	gchar *suri2;
	gboolean res;

	g_return_val_if_fail (source != NULL, FALSE);
	g_return_val_if_fail (uri != NULL, FALSE);

	suri = e_source_peek_absolute_uri (source);

	if (suri)
		return g_ascii_strcasecmp (suri, uri) == 0;

	suri2 = e_source_get_uri (source);
	res = suri2 && g_ascii_strcasecmp (suri2, uri) == 0;
	g_free (suri2);

	return res;
}

struct check_system_data
{
	const gchar *uri;
	ESource *uri_source;
};

static gboolean
check_system (ESource *source,
              gpointer data)
{
	struct check_system_data *csd = data;

	g_return_val_if_fail (source != NULL, FALSE);
	g_return_val_if_fail (data != NULL, FALSE);

	if (e_source_get_property (source, "system")) {
		return TRUE;
	}

	if (check_uri (source, (gpointer) csd->uri)) {
		if (csd->uri_source)
			g_object_unref (csd->uri_source);
		csd->uri_source = g_object_ref (source);
	}

	return FALSE;
}


static gboolean
ensure_local_addressbook (void)
{
  EBookClient *client;
  struct check_system_data csd;
  ESourceList *source_list = NULL;
  ESource *system_source = NULL;

  if (!e_book_client_get_sources (&source_list, NULL))
    return FALSE;

  csd.uri = "local:system";
  csd.uri_source = NULL;
  system_source = search_known_sources (source_list, check_system, &csd);

  if (system_source != NULL)
    contacts_eds_local_store = g_strdup (e_source_peek_uid (system_source));
  else if (csd.uri_source != NULL)
    contacts_eds_local_store = g_strdup (e_source_peek_uid (csd.uri_source));

  if (system_source)
    g_object_unref (system_source);
  if (csd.uri_source)
    g_object_unref (csd.uri_source);

  if (system_source != NULL ||
      csd.uri_source != NULL) {
    g_object_unref (source_list);
    return FALSE;
  }

  client = e_book_client_new_system (NULL);
  if (client != NULL) {
    contacts_eds_local_store = g_strdup (e_source_peek_uid (e_client_get_source (E_CLIENT (client))));
    g_object_unref (client);
    return TRUE;
  }
  return FALSE;
}

/* This is the property name or URL parameter under which we
 * embed the GoaAccount ID into an EAccount or ESource object. */
#define GOA_KEY "goa-account-id"

#define GOOGLE_BASE_URI "google://"

/* XXX Copy part of the private struct here so we can set our own UID.
 *     Since EAccountList and ESourceList forces the different aspects
 *     of the Google account to be disjoint, we can reuse the UID to
 *     link them back together. */
struct _ESourcePrivate {
	ESourceGroup *group;

	gchar *uid;
	/* ... yadda, yadda, yadda ... */
};

static void
online_accounts_google_sync_contacts (GoaObject *goa_object,
                                      const gchar *evo_id)
{
	GoaAccount *goa_account;
	ESourceList *source_list = NULL;
	ESourceGroup *source_group;
	ESource *source;
	const gchar *string;
	gboolean new_source = FALSE;
	GError *error = NULL;

	if (!e_book_get_addressbooks (&source_list, &error)) {
		g_warn_if_fail (source_list == NULL);
		g_warn_if_fail (error != NULL);
		g_warning ("%s", error->message);
		g_error_free (error);
		return;
	}

	g_return_if_fail (E_IS_SOURCE_LIST (source_list));

	goa_account = goa_object_get_account (goa_object);

	/* This returns a new reference to the source group. */
	source_group = e_source_list_ensure_group (
		source_list, evo_gettext ("Google"), GOOGLE_BASE_URI, TRUE);

	source = e_source_group_peek_source_by_uid (source_group, evo_id);

	if (source == NULL) {
		source = g_object_new (E_TYPE_SOURCE, NULL);
		source->priv->uid = g_strdup (evo_id);
		e_source_set_name (source, evo_gettext ("Contacts"));
		new_source = TRUE;
	}

	string = goa_account_get_identity (goa_account);

	e_source_set_relative_uri (source, string);

	e_source_set_property (source, "use-ssl", "true");
	e_source_set_property (source, "username", string);

	/* XXX Not sure this needs to be set since the backend
	 *     will authenticate itself if it sees a GOA ID. */
	e_source_set_property (source, "auth", "plain/password");

	string = goa_account_get_id (goa_account);
	e_source_set_property (source, GOA_KEY, string);

	if (new_source) {
		e_source_group_add_source (source_group, source, -1);
		g_object_unref (source);
	}

	/* If there is no current default then we likely want to use the GOA source by default. */
	if (search_known_sources (source_list, check_default, NULL) == NULL)
	  e_source_set_property (source, "default", "true");

	g_object_unref (source_group);
	g_object_unref (goa_account);

	g_object_unref (source_list);
}

static void
e_online_accounts_google_sync (GoaObject *goa_object,
                               const gchar *evo_id)
{
	GoaContacts *goa_contacts;

	g_return_if_fail (GOA_IS_OBJECT (goa_object));
	g_return_if_fail (evo_id != NULL);

	/*** Google Contacts ***/

	goa_contacts = goa_object_get_contacts (goa_object);
	if (goa_contacts != NULL) {
		online_accounts_google_sync_contacts (goa_object, evo_id);
		g_object_unref (goa_contacts);
	} else {
		ESourceList *source_list = NULL;
		GError *error = NULL;

		if (e_book_get_addressbooks (&source_list, &error)) {
			e_source_list_remove_source_by_uid (
				source_list, evo_id);
			g_object_unref (source_list);
		} else {
			g_warn_if_fail (source_list == NULL);
			g_warn_if_fail (error != NULL);
			g_warning ("%s", error->message);
			g_error_free (error);
		}
	}
}

struct SyncData {
  char *uid;
  GoaObject *goa_object;
};

static gboolean
sync_after_timeout (gpointer user_data)
{
  struct SyncData *data = user_data;

  e_online_accounts_google_sync (data->goa_object, data->uid);

  g_object_unref (data->goa_object);
  g_free (data->uid);
  g_free (data);

  return FALSE;
}

static void
online_accounts_account_added_cb (GoaClient *goa_client,
                                  GoaObject *goa_object)
{
	GoaAccount *goa_account;
	const gchar *provider_type;
	const gchar *goa_id;
	const gchar *evo_id;

	goa_account = goa_object_get_account (goa_object);
	provider_type = goa_account_get_provider_type (goa_account);

	goa_id = goa_account_get_id (goa_account);
	evo_id = g_hash_table_lookup (accounts, goa_id);

	if (g_strcmp0 (provider_type, "google") == 0) {
		if (evo_id == NULL) {
			gchar *uid = e_uid_new ();
			g_hash_table_insert (
				accounts,
				g_strdup (goa_id), uid);
			evo_id = uid;
		}

		// If this is not during startup, wait for
		// a while to let a running evo instance
		// create the account, this is a lame
		// fix for the race condition
		if (!contacts_avoid_goa_workaround) {
		  struct SyncData *data = g_new (struct SyncData, 1);
		  data->uid = g_strdup (evo_id);
		  data->goa_object = g_object_ref (goa_object);
		  g_timeout_add (3000, sync_after_timeout, data);
		} else {
		  e_online_accounts_google_sync (goa_object, evo_id);
		}
	}

	g_object_unref (goa_account);
}

static void
online_accounts_account_changed_cb (GoaClient *goa_client,
                                    GoaObject *goa_object)
{
	/* XXX We'll be able to handle changes more sanely once we have
	 *     key-file based ESources with proper change notifications. */
	online_accounts_account_added_cb (goa_client, goa_object);
}

static void
online_accounts_account_removed_cb (GoaClient *goa_client,
                                    GoaObject *goa_object)
{
	GoaAccount *goa_account;
	ESourceList *source_list;
	const gchar *goa_id;
	const gchar *evo_id;

	goa_account = goa_object_get_account (goa_object);
	goa_id = goa_account_get_id (goa_account);
	evo_id = g_hash_table_lookup (accounts, goa_id);

	if (evo_id == NULL)
		goto exit;

	/* Remove the address book. */

	if (e_book_get_addressbooks (&source_list, NULL)) {
		e_source_list_remove_source_by_uid (source_list, evo_id);
		g_object_unref (source_list);
	}

exit:
	g_object_unref (goa_account);
}

static gint
online_accounts_compare_id (GoaObject *goa_object,
                            const gchar *goa_id)
{
	GoaAccount *goa_account;
	gint result;

	goa_account = goa_object_get_account (goa_object);
	result = g_strcmp0 (goa_account_get_id (goa_account), goa_id);
	g_object_unref (goa_account);

	return result;
}

static void
online_accounts_handle_uid (const gchar *goa_id,
                            const gchar *evo_id)
{
	const gchar *match;

	/* If the GNOME Online Account ID is already registered, the
	 * corresponding Evolution ID better match what was passed in. */
	match = g_hash_table_lookup (accounts, goa_id);
	g_return_if_fail (match == NULL || g_strcmp0 (match, evo_id) == 0);

	if (match == NULL)
		g_hash_table_insert (
			accounts,
			g_strdup (goa_id),
			g_strdup (evo_id));
}

static void
online_accounts_search_source_list (GList *goa_objects,
                                    ESourceList *source_list)
{
	GSList *list_a;

	list_a = e_source_list_peek_groups (source_list);

	while (list_a != NULL) {
		ESourceGroup *source_group;
		GQueue trash = G_QUEUE_INIT;
		GSList *list_b;

		source_group = E_SOURCE_GROUP (list_a->data);
		list_a = g_slist_next (list_a);

		list_b = e_source_group_peek_sources (source_group);

		while (list_b != NULL) {
			ESource *source;
			const gchar *property;
			const gchar *uid;
			GList *match;

			source = E_SOURCE (list_b->data);
			list_b = g_slist_next (list_b);

			uid = e_source_peek_uid (source);
			property = e_source_get_property (source, GOA_KEY);

			if (property == NULL)
				continue;

			/* Verify the GOA account still exists. */
			match = g_list_find_custom (
				goa_objects, property, (GCompareFunc)
				online_accounts_compare_id);

			/* If a matching GoaObject was found, add its ID
			 * to our accounts hash table.  Otherwise remove
			 * the ESource after we finish looping. */
			if (match != NULL)
				online_accounts_handle_uid (property, uid);
			else
				g_queue_push_tail (&trash, source);
		}

		/* Empty the trash. */
		while (!g_queue_is_empty (&trash)) {
			ESource *source = g_queue_pop_head (&trash);
			e_source_group_remove_source (source_group, source);
		}
	}
}

static void
online_accounts_populate_accounts_table (GList *goa_objects)
{
	ESourceList *source_list;

	/* Search address book sources. */

	if (e_book_get_addressbooks (&source_list, NULL)) {
		online_accounts_search_source_list (goa_objects, source_list);
		g_object_unref (source_list);
	}
}

static void
online_accounts_connect_done (GObject *source_object,
                              GAsyncResult *result)
{
	GList *list, *link;
	GError *error = NULL;

	goa_client = goa_client_new_finish (result, &error);

	/* FIXME Add an EAlert for this? */
	if (error != NULL) {
		g_warning ("%s", error->message);
		g_error_free (error);
		goto out;
	}

	list = goa_client_get_accounts (goa_client);

	/* This populates a hash table of GOA ID -> Evo ID strings by
	 * searching through all Evolution sources for ones tagged with
	 * a GOA ID.  If a GOA ID tag is found, but no corresponding GOA
	 * account (presumably meaning the GOA account was deleted between
	 * Evo sessions), then the EAccount or ESource on which the tag was
	 * found gets deleted. */
	online_accounts_populate_accounts_table (list);

	for (link = list; link != NULL; link = g_list_next (link))
		online_accounts_account_added_cb (
			goa_client,
			GOA_OBJECT (link->data));

	g_list_free_full (list, (GDestroyNotify) g_object_unref);

	/* Listen for Online Account changes. */
	g_signal_connect (
		goa_client, "account-added",
		G_CALLBACK (online_accounts_account_added_cb), NULL);
	g_signal_connect (
		goa_client, "account-changed",
		G_CALLBACK (online_accounts_account_changed_cb), NULL);
	g_signal_connect (
		goa_client, "account-removed",
		G_CALLBACK (online_accounts_account_removed_cb), NULL);

 out:
	g_main_loop_quit (goa_loop);
}

static void
online_accounts_connect (void)
{
  accounts = g_hash_table_new_full ((GHashFunc) g_str_hash,
				    (GEqualFunc) g_str_equal,
				    (GDestroyNotify) g_free,
				    (GDestroyNotify) g_free);
  goa_client_new (NULL, (GAsyncReadyCallback)
		  online_accounts_connect_done, NULL);
}

void contacts_ensure_eds_accounts (void)
{

  created_local = ensure_local_addressbook ();

  goa_loop = g_main_loop_new (NULL, TRUE);
  contacts_avoid_goa_workaround = TRUE;

  online_accounts_connect ();

  if (g_main_loop_is_running (goa_loop))
    g_main_loop_run (goa_loop);

  g_main_loop_unref (goa_loop);
  goa_loop = NULL;
  contacts_avoid_goa_workaround = FALSE;

  contacts_source_list = NULL;
  e_book_get_addressbooks (&contacts_source_list, NULL);
}

gboolean contacts_has_goa_account (void)
{
  GSList *list_a;

  list_a = e_source_list_peek_groups (contacts_source_list);
  while (list_a != NULL) {
    ESourceGroup *source_group;
    GSList *list_b;

    source_group = E_SOURCE_GROUP (list_a->data);
    list_a = g_slist_next (list_a);

    list_b = e_source_group_peek_sources (source_group);

    while (list_b != NULL) {
      ESource *source;
      const gchar *property;
      const gchar *uid;
      GList *match;

      source = E_SOURCE (list_b->data);
      list_b = g_slist_next (list_b);

      uid = e_source_peek_uid (source);
      property = e_source_get_property (source, GOA_KEY);

      if (property == NULL)
	continue;

      return TRUE;
    }
  }

  return FALSE;
}


/* This is an enourmous hack to find google eds contacts that are
   in the "My Contacts" system group. */
char *
eds_personal_google_group_name (void)
{
  static char *name = NULL;
  char *domain;

  if (name == NULL) {
    domain = g_strdup_printf ("evolution-data-server-%d.%d\n",
			      EDS_MAJOR_VERSION,
			      EDS_MINOR_VERSION + ((EDS_MINOR_VERSION + 1) % 2));
    name = dgettext (domain, "Personal");
    g_free (domain);
  }

  return name;
}

gboolean
contacts_esource_uid_is_google (const char *uid)
{
  if (contacts_source_list) {
    ESource *source = e_source_list_peek_source_by_uid (contacts_source_list, uid);
    if (source) {
      const char *relative_uri = e_source_peek_relative_uri (source);
      if (relative_uri && g_str_has_suffix (relative_uri, "@gmail.com"))
	return TRUE;
    }
  }
  return FALSE;
}

const char *
contacts_lookup_esource_name_by_uid (const char *uid)
{
  if (strcmp (uid, contacts_eds_local_store) == 0)
    return _("Local Address Book");

  if (contacts_source_list) {
    ESource *source = e_source_list_peek_source_by_uid (contacts_source_list, uid);
    if (source) {
      const char *relative_uri = e_source_peek_relative_uri (source);
      if (relative_uri && g_str_has_suffix (relative_uri, "@gmail.com"))
	return  _("Google");

      return e_source_peek_name (source);
    }
  }
  return NULL;
}

const char *
contacts_lookup_esource_name_by_uid_for_contact (const char *uid)
{
  if (strcmp (uid, contacts_eds_local_store) == 0)
    return _("Local Contact");

  if (contacts_source_list) {
    ESource *source = e_source_list_peek_source_by_uid (contacts_source_list, uid);
    if (source) {
      const char *relative_uri = e_source_peek_relative_uri (source);
      if (relative_uri && g_str_has_suffix (relative_uri, "@gmail.com"))
	return  _("Google");

      return e_source_peek_name (source);
    }
  }
  return NULL;
}
