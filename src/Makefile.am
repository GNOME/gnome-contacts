NULL =

AM_CPPFLAGS = \
	-include config.h \
	$(CONTACTS_CFLAGS) \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\" \
	-DPKGLIBDIR=\""$(pkglibdir)"\" \
	-DGNOME_DESKTOP_USE_UNSTABLE_API \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir=$(srcdir)/../vapi --pkg config --pkg custom \
	@CONTACTS_PACKAGES@ \
	$(NULL)

if USE_GSTREAMER
AM_VALAFLAGS += -D HAVE_GSTREAMER @CONTACTS_GSTREAMER_PACKAGES@
AM_CPPFLAGS += $(CONTACTS_GSTREAMER_CFLAGS)
endif

bin_PROGRAMS = gnome-contacts

vala_sources = \
	contacts-app.vala \
	contacts-cell-renderer-shape.vala \
	contacts-contact.vala \
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
	contacts-esd-setup.c \
	$(vala_sources) \
	$(NULL)

gnome_contacts_LDADD = $(CONTACTS_LIBS) -lm

if USE_GSTREAMER
gnome_contacts_LDADD += $(CONTACTS_GSTREAMER_LIBS)
endif

CLEANFILES = \
	$(vala_sources:.vala=.c) \
	$(gsettings_SCHEMAS) \
	*.vapi *.stamp

EXTRA_DIST = \
	um-crop-area.h \
	gtk-notification.h   \
	contacts.gresource.xml \
	app-menu.ui \
	$(gsettingsschema_in_files)     \
	contacts-esd-setup.h \
	$(NULL)
