NULL=

desktopdir = $(datadir)/applications
desktop_in_files = org.gnome.Contacts.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

searchproviderdir = $(datadir)/gnome-shell/search-providers
searchprovider_DATA = org.gnome.Contacts.search-provider.ini

%.ini: %.ini.in
	LC_ALL=C $(INTLTOOL_MERGE) -d -u -c $(top_builddir)/po/.intltool-merge-cache $(top_srcdir)/po $< $@

@INTLTOOL_DESKTOP_RULE@

service_in_files = org.gnome.Contacts.SearchProvider.service.in

servicedir = $(datadir)/dbus-1/services
service_DATA = $(service_in_files:.service.in=.service) org.gnome.Contacts.service

%.service: %.service.in Makefile
	$(AM_V_GEN) [ -d $(@D) ] || $(mkdir_p) $(@D) ; \
	            sed -e "s|\@libexecdir\@|$(libexecdir)|" $< > $@.tmp && mv $@.tmp $@

org.gnome.Contacts.service:
	$(AM_V_GEN) (echo '[D-BUS Service]'; \
	            echo 'Name=org.gnome.Contacts'; \
	            echo 'Exec=${bindir}/gnome-contacts --gapplication-service') > $@.tmp && \
	            mv $@.tmp $@

@INTLTOOL_XML_RULE@
appdatadir = $(datadir)/appdata
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
appdata_in_files = org.gnome.Contacts.appdata.xml.in

EXTRA_DIST = \
	org.gnome.Contacts.desktop.in.in	\
	org.gnome.Contacts.search-provider.ini.in.in \
	contacts.gresource.xml \
	ui/app-menu.ui \
	ui/contacts-address-map.ui \
	ui/contacts-window.ui \
	ui/contacts-list-pane.ui \
	ui/style.css \
	$(appdata_in_files)	\
	$(service_in_files)  \
	$(NULL)

CLEANFILES = $(service_DATA)	\
	$(appdata_DATA)

DISTCLEANFILES = \
	org.gnome.Contacts.desktop \
	org.gnome.Contacts.search-provider.ini \
	gnome-contacts.desktop \
	gnome-contacts.desktop.in

private_icons =								\
	hicolor_apps_32x32_maps-pin.svg					\
	$(NULL)


install-icons:
	for icon in $(private_icons); do \
		THEME=`echo $$icon | cut -d_ -f1`; \
		CONTEXT=`echo $$icon | cut -d_ -f2`; \
		SIZE=`echo $$icon | cut -d_ -f3`; \
		ICONFILE=`echo $$icon | cut -d_ -f4`; \
		mkdir -p $(DESTDIR)$(datadir)/gnome-contacts/icons/$$THEME/$$SIZE/$$CONTEXT; \
		$(INSTALL_DATA) $(srcdir)/icons/$$icon $(DESTDIR)$(datadir)/gnome-contacts/icons/$$THEME/$$SIZE/$$CONTEXT/$$ICONFILE; \
	done

uninstall-icons:
	-for icon in $(private_icons); do \
		THEME=`echo $$icon | cut -d_ -f1`; \
		CONTEXT=`echo $$icon | cut -d_ -f2`; \
		SIZE=`echo $$icon | cut -d_ -f3`; \
		ICONFILE=`echo $$icon | cut -d_ -f4`; \
		rm -f $(DESTDIR)$(datadir)/gnome-contacts/icons/$$THEME/$$SIZE/$$CONTEXT/$$ICONFILE; \
	done

install-data-local: install-icons
