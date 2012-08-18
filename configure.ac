AC_PREREQ([2.67])
AC_INIT([gnome-contacts],[3.5.90],[http://bugzilla.gnome.org/enter_bug.cgi?product=gnome-contacts])
AC_CONFIG_SRCDIR([src/main.vala])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE
# Enable silent rules is available
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE([enable])
AC_CONFIG_FILES([Makefile
		vapi/Makefile
		src/Makefile
		data/Makefile
		po/Makefile.in
		data/gnome-contacts.desktop.in
		])

LT_INIT
AC_PROG_CC
AM_PROG_VALAC([0.17.2])
AC_PROG_INSTALL

GLIB_GSETTINGS

# i18n stuff
IT_PROG_INTLTOOL([0.40])

AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION([0.17])

GETTEXT_PACKAGE=gnome-contacts
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE], ["$GETTEXT_PACKAGE"], [Gettext Package])
AC_SUBST(GETTEXT_PACKAGE)


pkg_modules="gtk+-3.0 >= 3.4.0
	     glib-2.0 >= 2.31.10
	     gnome-desktop-3.0
	     folks >= 0.7.3
	     folks-telepathy
	     folks-eds
	     libnotify
	     telepathy-glib >= 0.17.5
	     libebook-1.2 >= 3.5.3
	     libedataserver-1.2 >= 3.5.3
	     goa-1.0
	     gee-1.0
	     "
PKG_CHECK_MODULES(CONTACTS, [$pkg_modules])

CONTACTS_PACKAGES="--pkg gtk+-3.0 --pkg gio-2.0 --pkg gio-unix-2.0 --pkg folks --pkg folks-telepathy --pkg folks-eds --pkg libnotify"
AC_SUBST(CONTACTS_PACKAGES)

gstreamers_modules="gdk-x11-3.0
                    gstreamer-0.10
                    gstreamer-interfaces-0.10
		    cheese-gtk >= 3.3.5
		    cheese
                    "

AC_MSG_CHECKING([whether to enable gstreamer/cheese support])
AC_ARG_ENABLE([gst],
    AS_HELP_STRING([--enable-gst], [Whether to enable gstreamer and cheese support @<:@default=auto@:>@]),
    [], [enable_gst=auto])
AC_MSG_RESULT([$enable_gst])
if test "$enable_gst" != "no"; then
    PKG_CHECK_MODULES(CONTACTS_GSTREAMER,
                  [$gstreamers_modules],
                  [have_gst=yes], [have_gst=no])
    if test "$enable_gst" = "yes" -a "$have_gst" = "no"; then
        AC_MSG_ERROR([GStreamer/Cheese support was requested but requirements were not met])
    elif test "$have_gst" = "yes"; then
        enable_gst=yes
    else
        enable_gst=no
    fi
fi

if test "$enable_gst" = "yes"; then
    AC_DEFINE([USE_GSTREAMER], 1,
            [Define to enable gstreamer/cheese support])
fi

AM_CONDITIONAL(USE_GSTREAMER, test "$enable_gst" = "yes")
CONTACTS_GSTREAMER_PACKAGES="--pkg gdk-x11-3.0 --pkg gstreamer-0.10 --pkg gstreamer-interfaces-0.10"
AC_SUBST(CONTACTS_GSTREAMER_PACKAGES)

#############
# Resources #
#############

GLIB_COMPILE_RESOURCES=`$PKG_CONFIG --variable glib_compile_resources gio-2.0`
AC_SUBST(GLIB_COMPILE_RESOURCES)

AC_OUTPUT
