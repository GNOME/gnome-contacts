void contacts_ensure_eds_accounts (void);
extern char *contacts_eds_local_store;
const char *contacts_lookup_esource_name_by_uid (const char *uid);
gboolean contacts_esource_uid_is_google (const char *uid);
char *eds_personal_google_group_name (void);
