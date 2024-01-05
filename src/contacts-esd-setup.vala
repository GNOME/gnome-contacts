/*
 * This code is ported to Vala from evolution with this license:
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

namespace Contacts {

public E.SourceRegistry? eds_source_registry = null;
// private E.CredentialsPrompter? eds_credentials_prompter = null;

public bool ensure_eds_accounts (bool allow_interaction) {
  if (eds_source_registry != null)
    return true;

  // XXX This blocks while connecting to the D-Bus service.
  // Maybe it should be created in the Contacts class and passed in as needed?

  try {
    eds_source_registry = new E.SourceRegistry.sync (null);
  } catch (Error e) { // If this fails it's game over.
    warning ("Couldn't load EDS SourceRegistry: %s", e.message);
    return false;
  }

  // FIXME Do when GTK4 port of e-d-s-ui is done
#if 0
  eds_credentials_prompter = new E.CredentialsPrompter (eds_source_registry);

  if (!allow_interaction)
      eds_credentials_prompter.set_auto_prompt (false);

  var credentials_provider = eds_credentials_prompter.get_provider ();

  // First disable credentials prompt for all but addressbook sources...
  foreach (var source in eds_source_registry.list_sources (null)) {
    // Mark for skip also currently disabled sources
    if (!source.has_extension (E.SOURCE_EXTENSION_ADDRESS_BOOK))
      eds_credentials_prompter.set_auto_prompt_disabled_for (source, true);
  }

  // ...then enable credentials prompt for credential source of the addressbook sources,
  //   which can be a collection source.
  foreach (var source in eds_source_registry.list_sources (E.SOURCE_EXTENSION_ADDRESS_BOOK)) {
    var cred_source = credentials_provider.ref_credentials_source (source);
    if (cred_source != null && !source.equal (cred_source))
      eds_credentials_prompter.set_auto_prompt_disabled_for (cred_source, false);
  }

  // The eds_credentials_prompter responses to REQUIRED and REJECTED reasons,
  // the SSL_FAILED should be handled elsewhere.
  eds_source_registry.credentials_required.connect((src, reason, cert_pem, cert_err, err) => {
      on_credentials_required.begin (src, reason, cert_pem, cert_err, err);
  });

  eds_credentials_prompter.process_awaiting_credentials ();
#endif

  return true;
}

// FIXME Do when GTK4 port of e-d-s-ui is done
#if 0
private async void on_credentials_required (E.Source source, E.SourceCredentialsReason reason, string cert_pem, TlsCertificateFlags cert_errors, Error err) {
  if (eds_credentials_prompter.get_auto_prompt_disabled_for (source))
    return;

   if (reason == E.SourceCredentialsReason.ERROR && err != null) {
     warning ("Failed to authenticate for source \"%s\": %s",
              source.display_name, err.message);
     return;
   }

   if (reason == E.SourceCredentialsReason.SSL_FAILED) {
     e_trust_prompt_run_for_source (eds_credentials_prompter.get_dialog_parent (),
        source, cert_pem, cert_errors, (err != null)? err.message : null, true,
        null, (obj, res) => on_source_trust_prompt_has_run.begin (source, res));
   }
}

private async void on_source_trust_prompt_has_run (E.Source source, AsyncResult res) {
  try {
    e_trust_prompt_run_for_source_finish (source, res, null);
  } catch (Error e) {
    warning ("Failed to prompt for trust for source \"%s\": %s", source.display_name, e.message);
    return;
  }

  try {
    // Use null credentials to reuse those from the last time.
    yield source.invoke_authenticate (null, null);
  } catch (Error e) {
    warning ("Failed to invoke authenticate() for source \"%s\": %s", source.display_name, e.message);
  }
}
#endif

public bool has_goa_account () {
  foreach (var source in eds_source_registry.list_sources (E.SOURCE_EXTENSION_GOA)) {
    // Ignore disabled accounts.
    if (!source.enabled)
      continue;

    // All ESources with a [GNOME Online Accounts] extension
    // should also have a [Collection] extension.  Verify it.
    if (!source.has_extension (E.SOURCE_EXTENSION_COLLECTION))
      continue;

    // This corresponds to the Contacts ON/OFF switch in GOA. */
    if (((E.SourceCollection) source.get_extension (E.SOURCE_EXTENSION_COLLECTION)).contacts_enabled) {
      return true;
    }
  }

  return false;
}

public bool esource_uid_is_google (string uid) {
  var source = eds_source_registry.ref_source (uid);
  if (source == null)
    return false;

  /* Make sure it's really an address book. */
  if (source.has_extension (E.SOURCE_EXTENSION_ADDRESS_BOOK)) {
    var extension = source.get_extension (E.SOURCE_EXTENSION_ADDRESS_BOOK);
    return ((E.SourceBackend) extension).backend_name == "google";
  }

  return false;
}

public string? lookup_esource_name_by_uid (string uid) {
  var source = eds_source_registry.ref_source (uid);
  if (source == null)
    return null;

  var builtin_address_book = eds_source_registry.ref_builtin_address_book ();

  if (source.equal (builtin_address_book))
    return _("Local Address Book");

  if (esource_uid_is_google (uid))
    return _("Google");

  return source.display_name;
}

public unowned string? lookup_esource_name_by_uid_for_contact (string uid) {
  var source = eds_source_registry.ref_source (uid);
  if (source == null)
    return null;

  var builtin_address_book = eds_source_registry.ref_builtin_address_book ();
  if (source.equal (builtin_address_book))
    return _("Local Contact");

  if (esource_uid_is_google (uid))
    return _("Google");

  return source.display_name;
}

public Gtk.Image? get_icon_for_goa_account (string goa_id) {
#if HAVE_GOA
  Goa.Client client;
  try {
    client = new Goa.Client.sync (null);
  } catch (Error e) {
    debug ("Couldn't load GOA client \"%s\": %s", goa_id, e.message);
    return null;
  }

  var goa_object = client.lookup_by_id (goa_id);

  Icon provider_icon;
  try {
    provider_icon = Icon.new_for_string (goa_object.account.provider_icon);
  } catch (Error e) {
    debug ("Couldn't load icon for GOA provider \"%s\"", goa_id);
    return null;
  }

  return new Gtk.Image.from_gicon (provider_icon);
#else
  return null;
#endif
}
}
