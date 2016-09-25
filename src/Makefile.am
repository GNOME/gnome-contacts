NULL =

AM_CPPFLAGS = \
	-include config.h \
	$(CONTACTS_CFLAGS) \
	-I$(top_srcdir)/libgd \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\" \
	-DPKGLIBDIR=\""$(pkglibdir)"\" \
	-DGNOME_DESKTOP_USE_UNSTABLE_API \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir=../vapi --vapidir=../libgd --pkg config --pkg custom --pkg gd-1.0 \
	@CONTACTS_PACKAGES@ \
	--target-glib=2.38 --gresources=$(top_srcdir)/data/contacts.gresource.xml \
	$(NULL)

if BUILD_CHEESE
AM_VALAFLAGS += -D HAVE_CHEESE
AM_CPPFLAGS += $(CHEESE_CFLAGS)
endif

bin_PROGRAMS = gnome-contacts

vala_sources = \
	contacts-app.vala \
	contacts-address-map.vala \
	contacts-contact.vala \
	contacts-contact-sheet.vala \
	contacts-contact-editor.vala \
	contacts-contact-pane.vala \
	contacts-types.vala \
	contacts-list-pane.vala \
	contacts-linked-accounts-dialog.vala \
	contacts-linking.vala \
	contacts-store.vala \
	contacts-view.vala \
	contacts-utils.vala \
	contacts-avatar-dialog.vala \
	contacts-accounts-list.vala \
	contacts-contact-frame.vala \
	contacts-window.vala \
	main.vala \
	$(NULL)

gsettings_ENUM_NAMESPACE = org.gnome.Contacts
gsettings_ENUM_FILES = \
        contacts-view.c

gsettings_SCHEMAS = org.gnome.Contacts.gschema.xml

@GSETTINGS_RULES@

resource_files = $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=$(top_srcdir)/data $(top_srcdir)/data/contacts.gresource.xml)
contact-resources.c: $(top_srcdir)/data/contacts.gresource.xml $(resource_files)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(top_srcdir)/data --generate-source $<

gnome_contacts_SOURCES = \
	$(vala_sources) \
	um-crop-area.c \
	contact-resources.c \
	contacts-esd-setup.c \
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
	*.vapi *.stamp

EXTRA_DIST = \
	org.gnome.Contacts.gschema.xml \
	cheese-flash.h \
	um-crop-area.h \
	contacts-esd-setup.h \
	$(NULL)
