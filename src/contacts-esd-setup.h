#include <libedataserver/e-source-list.h>

void contacts_ensure_eds_accounts (void);
extern char *contacts_eds_local_store;
const char *contacts_lookup_esource_name_by_uid (const char *uid);
const char *contacts_lookup_esource_name_by_uid_for_contact (const char *uid);
gboolean contacts_esource_uid_is_google (const char *uid);
char *eds_personal_google_group_name (void);
gboolean contacts_has_goa_account (void);
extern ESourceList *contacts_source_list;
extern gboolean contacts_avoid_goa_workaround;
