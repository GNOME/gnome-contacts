# Core library
libcontactscore_sources = files(
  'contacts-addresses-chunk.vala',
  'contacts-alias-chunk.vala',
  'contacts-avatar-chunk.vala',
  'contacts-bin-chunk.vala',
  'contacts-birthday-chunk.vala',
  'contacts-chunk.vala',
  'contacts-contact.vala',
  'contacts-email-addresses-chunk.vala',
  'contacts-full-name-chunk.vala',
  'contacts-im-addresses-chunk.vala',
  'contacts-nickname-chunk.vala',
  'contacts-notes-chunk.vala',
  'contacts-phones-chunk.vala',
  'contacts-roles-chunk.vala',
  'contacts-structured-name-chunk.vala',
  'contacts-type-descriptor.vala',
  'contacts-type-set.vala',
  'contacts-urls-chunk.vala',
  'contacts-vcard-type-mapping.vala',
)

libcontactscore_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
  '--pkg', 'config',
]

libcontactscore_c_args = [
  '-include', 'config.h',
]

libcontactscore_deps = [
  folks,
  folks_eds,
  gee,
  glib,
]

libcontactscore = static_library('contactscore',
  libcontactscore_sources,
  include_directories: config_h_dir,
  vala_args: libcontactscore_vala_args,
  c_args: libcontactscore_c_args,
  dependencies: libcontactscore_deps,
)

libcontactscore_dep = declare_dependency(
  link_with: libcontactscore,
  include_directories: include_directories('.'),
  dependencies: libcontactscore_deps,
)
