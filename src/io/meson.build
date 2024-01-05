contacts_io_sources = files(
  'contacts-io-parser.vala',
  'contacts-io-vcard-parser.vala',
  'contacts-io.vala',
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

contacts_io_deps = [
  libcontactscore_dep,
  folks,
  folks_eds,
  gee,
  gio_unix,
  glib,
  libebook,
]

executable('gnome-contacts-parser',
  contacts_io_sources + [ 'contacts-io-parse-main.vala' ],
  dependencies: contacts_io_deps,
  install: true,
  install_dir: get_option('libexecdir') / 'gnome-contacts',
)
