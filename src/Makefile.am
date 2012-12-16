NULL =

AM_CPPFLAGS = \
	-include config.h \
	$(CONTACTS_CFLAGS) \
	-I$(srcdir)/listbox \
	-I$(top_srcdir)/libgd \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\" \
	-DPKGLIBDIR=\""$(pkglibdir)"\" \
	-DGNOME_DESKTOP_USE_UNSTABLE_API \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir=$(srcdir)/../vapi --vapidir=$(srcdir)/listbox --vapidir=$(top_srcdir)/libgd --pkg config --pkg custom --pkg egglistbox --pkg gd-1.0 \
	@CONTACTS_PACKAGES@ \
	$(NULL)

if BUILD_CHEESE
AM_VALAFLAGS += -D HAVE_CHEESE
AM_CPPFLAGS += $(CHEESE_CFLAGS)
endif

bin_PROGRAMS = gnome-contacts

vala_sources = \
	contacts-app.vala \
	contacts-contact.vala \
	contacts-contact-sheet.vala \
	contacts-contact-pane.vala \
	contacts-types.vala \
	contacts-list-pane.vala \
	contacts-link-dialog.vala \
	contacts-linking.vala \
	contacts-menu-button.vala \
	contacts-row.vala \
	contacts-store.vala \
	contacts-view.vala \
	contacts-utils.vala \
	contacts-clickable.vala \
	contacts-new-contact-dialog.vala \
	contacts-avatar-dialog.vala \
	contacts-contact-frame.vala \
	contacts-revealer.vala \
	contacts-setup-window.vala \
	contacts-window.vala \
	main.vala \
	memory-icon.vala \
	$(NULL)

gsettingsschema_in_files = org.gnome.Contacts.gschema.xml.in
gsettings_SCHEMAS = $(gsettingsschema_in_files:.xml.in=.xml)
.PRECIOUS: $(gsettings_SCHEMAS)

@INTLTOOL_XML_NOMERGE_RULE@

@GSETTINGS_RULES@

contact-resources.c: contacts.gresource.xml app-menu.ui
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) $(srcdir)/contacts.gresource.xml \
		--target=$@ --sourcedir=$(srcdir) --c-name contacts --generate-source

gnome_contacts_SOURCES = \
	um-crop-area.c \
	contact-resources.c \
	gtk-notification.c   \
	listbox/egg-list-box.c \
	contacts-esd-setup.c \
	$(vala_sources) \
	$(NULL)

gnome_contacts_LDADD = $(CONTACTS_LIBS) -lm $(top_builddir)/libgd/libgd.la

if BUILD_CHEESE
gnome_contacts_LDADD += $(CHEESE_LIBS)
gnome_contacts_SOURCES += \
	cheese-flash.c \
	$(NULL)
endif

libexec_PROGRAMS = gnome-contacts-search-provider

gnome_contacts_search_provider_SOURCES = \
	contacts-contact.vala \
	contacts-esd-setup.c \
	contacts-shell-search-provider.vala \
	contacts-store.vala \
	contacts-types.vala \
	contacts-utils.vala \
	$(NULL)

gnome_contacts_search_provider_LDADD = $(CONTACTS_LIBS)

CLEANFILES = \
	$(vala_sources:.vala=.c) \
	$(gsettings_SCHEMAS) \
	*.vapi *.stamp

EXTRA_DIST = \
	listbox/egg-list-box.h \
	listbox/egglistbox.vapi \
	cheese-flash.h \
	um-crop-area.h \
	gtk-notification.h   \
	contacts.gresource.xml \
	app-menu.ui \
	$(gsettingsschema_in_files)     \
	contacts-esd-setup.h \
	$(NULL)
