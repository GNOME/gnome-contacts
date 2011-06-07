NULL =

AM_CPPFLAGS = \
	-include config.h \
	$(CONTACTS_CFLAGS) \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\" \
	-DPKGLIBDIR=\""$(pkglibdir)"\" \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir=$(srcdir)/../vapi --pkg config \
	@CONTACTS_PACKAGES@ \
	$(NULL)

bin_PROGRAMS = gnome-contacts

gnome_contacts_SOURCES = \
	contacts-app.vala \
	contacts-contact.vala \
	contacts-menu-button.vala \
	contacts-hover-image.vala \
	contacts-store.vala \
	contacts-clickable.vala \
	main.vala \
	$(NULL)

gnome_contacts_LDADD = $(CONTACTS_LIBS)

CLEANFILES = *.h *.c *.vapi *.stamp
