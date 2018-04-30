[CCode (lower_case_cprefix = "", cheader_filename = "config.h")]
namespace Config {
public const string APP_ID;

/* Package information */
public const string PACKAGE_NAME;
public const string PACKAGE_STRING;
public const string PACKAGE_VERSION;

/* Gettext package */
public const string GETTEXT_PACKAGE;

/* Configured paths - these variables are not present in config.h, they are
* passed to underlying C code as cmd line macros. */
public const string LOCALEDIR; /* /usr/local/share/locale */
public const string PKGDATADIR; /* /usr/local/share/gnome-contacts */
public const string PKGLIBDIR; /* /usr/local/lib/gnome-contacts */
}

