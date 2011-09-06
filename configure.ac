AC_PREREQ([2.67])
AC_INIT([gnome-contacts],[0.1.4],[http://bugzilla.gnome.org/enter_bug.cgi?product=gnome-contacts])
AC_CONFIG_SRCDIR([src/main.vala])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE
# Enable silent rules is available
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE
AC_CONFIG_FILES([Makefile
		vapi/Makefile
		src/Makefile
		data/Makefile
		po/Makefile.in
		data/gnome-contacts.desktop.in
		])

LT_INIT
AC_PROG_CC
AM_PROG_VALAC([0.13.0])
AC_PROG_INSTALL
IT_PROG_INTLTOOL([0.35])

GETTEXT_PACKAGE=gnome-contacts
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], ["$GETTEXT_PACKAGE"], [Gettext Package])
AC_SUBST(GETTEXT_PACKAGE)
AM_GNU_GETTEXT_VERSION([1.11])
AM_GLIB_GNU_GETTEXT

pkg_modules="gtk+-3.0
	     gnome-desktop-3.0
	     folks >= 0.6.1.1
	     folks-telepathy
	     libnotify
	     "
PKG_CHECK_MODULES(CONTACTS, [$pkg_modules])
CONTACTS_PACKAGES="--pkg gtk+-3.0 --pkg gio-2.0 --pkg folks --pkg folks-telepathy --pkg libnotify"
AC_SUBST(CONTACTS_CFLAGS)
AC_SUBST(CONTACTS_LIBS)
AC_SUBST(CONTACTS_PACKAGES)

AC_OUTPUT
