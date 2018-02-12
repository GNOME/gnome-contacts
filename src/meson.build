# GSettings
compiled = gnome.compile_schemas()
install_data('org.gnome.Contacts.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
)

# The gnome-contacts binary
contacts_vala_sources = [
  'contacts-accounts-list.vala',
  'contacts-app.vala',
  'contacts-avatar.vala',
  'contacts-avatar-selector.vala',
  'contacts-contact-editor.vala',
  'contacts-contact-list.vala',
  'contacts-contact-pane.vala',
  'contacts-contact-sheet.vala',
  'contacts-contact.vala',
  'contacts-esd-setup.vala',
  'contacts-in-app-notification.vala',
  'contacts-link-suggestion-grid.vala',
  'contacts-linked-personas-dialog.vala',
  'contacts-linking.vala',
  'contacts-list-pane.vala',
  'contacts-settings.vala',
  'contacts-setup-window.vala',
  'contacts-store.vala',
  'contacts-types.vala',
  'contacts-ui-state.vala',
  'contacts-utils.vala',
  'contacts-window.vala',
  'main.vala',
]

contacts_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
  '--pkg', 'config',
  '--pkg', 'custom',
]

contacts_c_sources = [
  'cc-crop-area.c',
]

contacts_c_args = [
  '-include', 'config.h',
  '-DGNOME_DESKTOP_USE_UNSTABLE_API',
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
  math,
]

# Add extra stuff given a certain set of options
if cheese_enabled
  contacts_deps += [ cheese, cheese_gtk ]
  contacts_vala_args += [ '-D', 'HAVE_CHEESE' ]
  contacts_c_sources += 'cheese-flash.c'
endif

if telepathy_enabled
  contacts_deps += [ folks_telepathy, telepathy_glib ]
  contacts_vala_args += [ '-D', 'HAVE_TELEPATHY' ]
  contacts_vala_sources += [ 'contacts-im-service.vala' ]
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
  dependencies: contacts_deps,
  install: true,
)

# The search provider
contact_search_provider_sources = [
  'contacts-contact.vala',
  'contacts-esd-setup.vala',
  'contacts-shell-search-provider.vala',
  'contacts-store.vala',
  'contacts-types.vala',
  'contacts-utils.vala',
]

executable('gnome-contacts-search-provider', contact_search_provider_sources,
  include_directories: config_h_dir,
  vala_args: contacts_vala_args,
  c_args: contacts_c_args,
  dependencies: contacts_deps,
  install: true,
  install_dir: libexecdir,
)
