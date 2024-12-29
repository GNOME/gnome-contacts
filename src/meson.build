subdir('core')
subdir('io')

# GSettings
compiled = gnome.compile_schemas()
install_data('org.gnome.Contacts.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)

# Validates gsettings file

# Common library
libcontacts_sources = files(
  'contacts-chunk-filter.vala',
  'contacts-chunk-empty-filter.vala',
  'contacts-chunk-property-filter.vala',
  'contacts-chunk-sorter.vala',
  'contacts-delete-operation.vala',
  'contacts-esd-setup.vala',
  'contacts-im-service.vala',
  'contacts-import-operation.vala',
  'contacts-individual-section-sorter.vala',
  'contacts-individual-sorter.vala',
  'contacts-link-operation.vala',
  'contacts-manual-filter.vala',
  'contacts-operation.vala',
  'contacts-operation-list.vala',
  'contacts-persona-filter.vala',
  'contacts-persona-sorter.vala',
  'contacts-query-filter.vala',
  'contacts-store.vala',
  'contacts-unlink-operation.vala',
  'contacts-utils.vala',

  'io/contacts-io-export-operation.vala',
  'io/contacts-io-vcard-export-operation.vala',
  'io/contacts-io-parse-operation.vala',
  'io/contacts-io.vala',
)

contacts_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
  '--pkg', 'config',
  '--pkg', 'custom',
]

contacts_c_args = [
  '-include', 'config.h',
  '-DLOCALEDIR="@0@"'.format(locale_dir),
]

contacts_deps = [
  libcontactscore_dep,
  folks,
  folks_eds,
  gee,
  gio_unix,
  glib,
  gstreamer_dep,
  gtk4_dep,
  libadwaita_dep,
  libebook,
  libedataserver,
  libportal_dep,
  math,
  libqrencode_dep,
]

if get_option('goa')
  contacts_deps += [ goa_dep ]
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
  'contacts-accounts-list.vala',
  'contacts-app.vala',
  'contacts-avatar.vala',
  'contacts-avatar-selector.vala',
  'contacts-contact-editor.vala',
  'contacts-contact-list.vala',
  'contacts-contact-pane.vala',
  'contacts-contact-selection-model.vala',
  'contacts-contact-sheet-row.vala',
  'contacts-contact-sheet.vala',
  'contacts-crop-dialog.vala',
  'contacts-editable-avatar.vala',
  'contacts-import-dialog.vala',
  'contacts-link-suggestion-grid.vala',
  'contacts-main-window.vala',
  'contacts-qr-code-dialog.vala',
  'contacts-preferences-window.vala',
  'contacts-settings.vala',
  'contacts-setup-window.vala',
  'contacts-type-combo.vala',
  'contacts-ui-state.vala',
  'main.vala',
)

contacts_c_sources = [
  'cc-crop-area.c',
]

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
  install_dir: get_option('libexecdir'),
)
