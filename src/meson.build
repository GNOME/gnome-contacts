compiled = gnome.compile_schemas()
install_data('org.gnome.Contacts.gschema.xml',
  install_dir: 'share/glib-2.0/schemas'
)

contacts_vala_sources = [
  'contacts-accounts-list.vala',
  'contacts-address-map.vala',
  'contacts-app.vala',
  'contacts-avatar-dialog.vala',
  'contacts-contact-editor.vala',
  'contacts-contact-frame.vala',
  'contacts-contact-pane.vala',
  'contacts-contact-sheet.vala',
  'contacts-contact.vala',
  'contacts-in-app-notification.vala',
  'contacts-linked-accounts-dialog.vala',
  'contacts-linking.vala',
  'contacts-list-pane.vala',
  'contacts-settings.vala',
  'contacts-store.vala',
  'contacts-types.vala',
  'contacts-utils.vala',
  'contacts-view.vala',
  'contacts-window.vala',
  'main.vala',
]

contacts_vala_args = [
  '--target-glib=2.38',
  '--pkg', 'config',
  '--pkg', 'custom',
]

contacts_c_sources = [
  'cc-crop-area.c',
  'contacts-esd-setup.c',
]

contacts_c_args = [
  '-include', 'config.h',
  '-DGNOME_DESKTOP_USE_UNSTABLE_API',
  '-DLOCALEDIR="@0@"'.format(locale_dir),
]

contacts_sources = [
  contacts_c_sources,
  contacts_vala_sources,
  resources,
]

contacts_deps = [
  champlain,
  clutter_gtk,
  folks,
  folks_eds,
  folks_telepathy,
  gee,
  geocode_glib,
  gio_unix,
  glib,
  gnome_desktop,
  goa,
  gtk,
  libebook,
  libedataserver,
  libedataserverui,
  math,
  telepathy_glib,
]

# Add extra stuff if cheese is enabled
if get_option('with-cheese')
  contacts_deps += [ cheese, cheese_gtk ]
  contacts_vala_args += [ '-D', 'HAVE_CHEESE' ]
  contacts_c_sources += 'cheese-flash.c'
endif

executable('gnome-contacts', contacts_sources,
  include_directories: config_h_dir,
  vala_args: contacts_vala_args,
  c_args: contacts_c_args,
  dependencies: contacts_deps,
  install: true,
)

# The search provider
contact_search_provider_vala_sources = [
  'contacts-contact.vala',
  'contacts-shell-search-provider.vala',
  'contacts-store.vala',
  'contacts-types.vala',
  'contacts-utils.vala',
]

contact_search_provider_c_sources = [
  'contacts-esd-setup.c',
]

contact_search_provider_sources = [
  contact_search_provider_vala_sources,
  contact_search_provider_c_sources,
]

executable('gnome-contacts-search-provider', contact_search_provider_sources,
  include_directories: config_h_dir,
  vala_args: contacts_vala_args,
  c_args: contacts_c_args,
  dependencies: contacts_deps,
  install: true,
)
