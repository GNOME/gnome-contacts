# Common library
contacts_io_sources = files(
  'contacts-io.vala',
  'contacts-io-importer.vala',
  'contacts-io-vcard-importer.vala',
)

contacts_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
  '--pkg', 'config',
  '--pkg', 'custom',
]

contacts_c_args = [
  '-include', 'config.h',
  '-DGNOME_DESKTOP_USE_UNSTABLE_API',
  '-DLOCALEDIR="@0@"'.format(locale_dir),
]

contacts_io_deps = [
  folks,
  gee,
  gio_unix,
  glib,
  libebook,
]

executable('gnome-contacts-import',
  [ contacts_io_sources, files('contacts-io-import-main.vala') ],
  dependencies: contacts_io_deps,
  install: true,
  install_dir: get_option('libexecdir') / 'gnome-contacts',
)
