NULL =

org.gnome.Contacts.desktop: org.gnome.Contacts.desktop.in
	$(AM_V_GEN)$(MSGFMT) --desktop --template $< -d $(top_srcdir)/po -o $@
desktopdir = $(datadir)/applications
desktop_DATA = org.gnome.Contacts.desktop

org.gnome.Contacts.appdata.xml: org.gnome.Contacts.appdata.xml.in
	$(AM_V_GEN)$(MSGFMT) --xml --template $< -d $(top_srcdir)/po -o $@
appdatadir = $(datadir)/appdata
appdata_DATA = org.gnome.Contacts.appdata.xml

searchproviderdir = $(datadir)/gnome-shell/search-providers
searchprovider_DATA = org.gnome.Contacts.search-provider.ini

servicedir = $(datadir)/dbus-1/services
service_DATA = \
	org.gnome.Contacts.SearchProvider.service \
	org.gnome.Contacts.service

%.service: %.service.in Makefile
	$(AM_V_GEN) [ -d $(@D) ] || $(mkdir_p) $(@D) ; \
	            sed -e "s|\@libexecdir\@|$(libexecdir)|" $< > $@.tmp && mv $@.tmp $@

org.gnome.Contacts.service:
	$(AM_V_GEN) (echo '[D-BUS Service]'; \
	            echo 'Name=org.gnome.Contacts'; \
	            echo 'Exec=${bindir}/gnome-contacts --gapplication-service') > $@.tmp && \
	            mv $@.tmp $@

EXTRA_DIST = \
	org.gnome.Contacts.desktop.in \
	org.gnome.Contacts.appdata.xml.in \
	org.gnome.Contacts.search-provider.ini \
	org.gnome.Contacts.SearchProvider.service.in \
	contacts.gresource.xml \
	ui/app-menu.ui \
	ui/contacts-address-map.ui \
	ui/contacts-in-app-notification.ui \
	ui/contacts-list-pane.ui \
	ui/contacts-window.ui \
	ui/style.css \
	$(NULL)

CLEANFILES = \
	$(service_DATA)	\
	org.gnome.Contacts.desktop \
	org.gnome.Contacts.appdata.xml \
	org.gnome.Contacts.SearchProvider.service \
	$(appdata_DATA)

DISTCLEANFILES = \
	org.gnome.Contacts.desktop \
	org.gnome.Contacts.appdata.xml \
	org.gnome.Contacts.SearchProvider.service

