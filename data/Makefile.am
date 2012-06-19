NULL=

desktopdir = $(datadir)/applications
desktop_in_files = gnome-contacts.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

searchproviderdir = $(datadir)/gnome-shell/search-providers
searchprovider_DATA = gnome-contacts-search-provider.ini
searchprovider_in_files = gnome-contacts-search-provider.ini.in

%.ini: %.ini.in
	LC_ALL=C $(INTLTOOL_MERGE) -d -u -c $(top_builddir)/po/.intltool-merge-cache $(top_srcdir)/po $< $@

@INTLTOOL_DESKTOP_RULE@

service_in_files = org.gnome.Contacts.SearchProvider.service.in

servicedir = $(datadir)/dbus-1/services
service_DATA = $(service_in_files:.service.in=.service)

%.service: %.service.in Makefile
	$(AM_V_GEN) [ -d $(@D) ] || $(mkdir_p) $(@D) ; \
	            sed -e "s|\@libexecdir\@|$(libexecdir)|" $< > $@.tmp && mv $@.tmp $@

EXTRA_DIST = \
	gnome-contacts.desktop.in.in	\
	$(searchprovider_DATA) 	\
	$(service_in_files)  \
	$(NULL)

CLEANFILES = $(service_DATA)
DISTCLEANFILES = \
	gnome-contacts.desktop \
	gnome-contacts.desktop.in
