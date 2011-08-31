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

bin_PROGRAMS = gnome-contacts

gnome_contacts_SOURCES = \
	contacts-app.vala \
	contacts-cell-renderer-shape.vala \
	contacts-contact.vala \
	contacts-contact-pane.vala \
	contacts-types.vala \
	contacts-list-pane.vala \
	contacts-link-dialog.vala \
	contacts-menu-button.vala \
	contacts-store.vala \
	contacts-view.vala \
	contacts-utils.vala \
	main.vala \
	$(NULL)

gnome_contacts_LDADD = $(CONTACTS_LIBS) -lm

CLEANFILES = *.h *.c *.vapi *.stamp
