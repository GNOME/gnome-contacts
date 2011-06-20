NULL=

pkgdatadir = $(datadir)/gnome-contacts

pkgdata_DATA = \
	gnome-contacts.css			\
	$(NULL)

desktopdir = $(datadir)/applications
desktop_in_files = gnome-contacts.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = \
	$(pkgdata_DATA)	\
	gnome-contacts.desktop.in.in	\
	$(NULL)

DISTCLEANFILES = \
	gnome-contacts.desktop \
	gnome-contacts.desktop.in
