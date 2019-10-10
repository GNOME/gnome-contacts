# GSettings
compiled = gnome.compile_schemas()
install_data('org.gnome.Contacts.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
)

# Common library
libcontacts_sources = files(
  'contacts-contact.vala',
  'contacts-esd-setup.vala',
  'contacts-fake-persona-store.vala',
  'contacts-im-service.vala',
  'contacts-store.vala',
  'contacts-typeset.vala',
  'contacts-type-descriptor.vala',
  'contacts-utils.vala',
  'contacts-avatar-utils.vala',
  'contacts-vcard-type-mapping.vala',
)

contacts_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
  '--pkg', 'config',
  '--pkg', 'custom',
]

contacts_c_args = [
  '-include', 'config.h',
  '-DGNOME_DESKTOP_USE_UNSTABLE_API',
  '-DHANDY_USE_UNSTABLE_API',
  '-DLOCALEDIR="@0@"'.format(locale_dir),
]

contacts_deps = [
  folks,
  folks_eds,
  gee,
  gio_unix,
  glib,
  gnome_desktop,
  goa,
  gtk,
  libebook,
  libedataserver,
  libedataserverui,
  libhandy,
  math,
]

# Add extra stuff given a certain set of options
if cheese_enabled
  contacts_deps += [ cheese, cheese_gtk ]
  contacts_vala_args += [ '-D', 'HAVE_CHEESE' ]
endif

if telepathy_enabled
  contacts_deps += [ folks_telepathy, telepathy_glib ]
  contacts_vala_args += [ '-D', 'HAVE_TELEPATHY' ]
endif

libcontacts = static_library('contacts',
  libcontacts_sources,
  include_directories: config_h_dir,
  vala_args: contacts_vala_args,
  c_args: contacts_c_args,
  dependencies: contacts_deps,
)

libcontacts_dep = declare_dependency(
  link_with: libcontacts,
  include_directories: include_directories('.'),
  dependencies: contacts_deps,
)


# The gnome-contacts binary
contacts_vala_sources = files(
  'contacts-addressbook-list.vala',
  'contacts-accounts-list.vala',
  'contacts-app.vala',
  'contacts-avatar.vala',
  'contacts-avatar-selector.vala',
  'contacts-contact-editor.vala',
  'contacts-contact-list.vala',
  'contacts-contact-pane.vala',
  'contacts-contact-sheet.vala',
  'contacts-crop-cheese-dialog.vala',
  'contacts-editor-persona.vala',
	'contacts-editor-property.vala',
  'contacts-in-app-notification.vala',
  'contacts-link-suggestion-grid.vala',
  'contacts-linking.vala',
  'contacts-list-pane.vala',
  'contacts-settings.vala',
  'contacts-setup-window.vala',
  'contacts-type-combo.vala',
  'contacts-ui-state.vala',
  'contacts-window.vala',
  'main.vala',
)

contacts_c_sources = [
  'cc-crop-area.c',
]

if cheese_enabled
  contacts_c_sources += 'cheese-flash.c'
endif

contacts_sources = [
  contacts_c_sources,
  contacts_vala_sources,
  resources,
]

executable('gnome-contacts', contacts_sources,
  include_directories: config_h_dir,
  vala_args: contacts_vala_args,
  c_args: contacts_c_args,
  dependencies: libcontacts_dep,
  install: true,
)


# The search provider
executable('gnome-contacts-search-provider',
  'contacts-shell-search-provider.vala',
  dependencies: libcontacts_dep,
  include_directories: config_h_dir,
  vala_args: contacts_vala_args,
  c_args: contacts_c_args,
  install: true,
  install_dir: libexecdir,
)
