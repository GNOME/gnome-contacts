#include <libebook/libebook.h>

void contacts_ensure_eds_accounts (void);
const char *contacts_lookup_esource_name_by_uid (const char *uid);
const char *contacts_lookup_esource_name_by_uid_for_contact (const char *uid);
gboolean contacts_esource_uid_is_google (const char *uid);
char *eds_personal_google_group_name (void);
gboolean contacts_has_goa_account (void);
extern ESourceRegistry *eds_source_registry;
extern gboolean contacts_avoid_goa_workaround;
