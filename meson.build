project('gnome-contacts', [ 'vala', 'c' ],
  version: '49.0',
  license: 'GPL-2.0-or-later',
  meson_version: '>= 1.0',
)

gnome = import('gnome')
i18n = import('i18n')

# Add our custom VAPI dir
add_project_arguments(
  ['--vapidir', meson.project_source_root() / 'vapi'],
  language: 'vala'
)

# Application ID
if get_option('profile') == 'development'
  contacts_app_id = 'org.gnome.Contacts.Devel'
else
  contacts_app_id = 'org.gnome.Contacts'
endif

# Common variables
valac = meson.get_compiler('vala')
config_h_dir = include_directories('.')
contacts_prefix = get_option('prefix')
locale_dir = contacts_prefix / get_option('localedir')
po_dir = meson.project_source_root() / 'po'

# Dependencies
min_eds_version = '3.42'
min_folks_version = '0.14'
min_glib_version = '2.64' # We also use this value for --target-glib, so scratch the micro version.

# We know that compiling on a lower version doesn't work
min_vala_version = '0.56.11'
if valac.version().version_compare('<' + min_vala_version)
  error('Your Vala installation is too old (@0@).'.format(valac.version())
      + ' Please make sure you have at least Vala ' + min_vala_version)
endif

math = meson.get_compiler('c').find_library('m')

folks = dependency('folks', version: '>=' + min_folks_version)
folks_eds = dependency('folks-eds', version: '>=' + min_folks_version)
gee = dependency('gee-0.8')
gio_unix = dependency('gio-unix-2.0', version: '>=' + min_glib_version)
glib = dependency('glib-2.0', version: '>=' + min_glib_version)
gmodule_export = dependency('gmodule-export-2.0', version: '>=' + min_glib_version)
gtk4_dep = dependency('gtk4', version: '>= 4.15.3')
libadwaita_dep = dependency('libadwaita-1', version: '>= 1.8.alpha')
# E-D-S
libebook = dependency('libebook-1.2', version: '>=' + min_eds_version)
libedataserver = dependency('libedataserver-1.2', version: '>=' + min_eds_version)
# Camera
libportal_dep = dependency('libportal-gtk4', version: '>= 0.7')
gstreamer_dep = dependency('gstreamer-1.0')
# QR Code
libqrencode_dep = dependency('libqrencode', version: '>=4.1.1')
# gnome-online-accounts
if get_option('goa')
  goa_dep = dependency('goa-1.0')
  add_project_arguments('-D', 'HAVE_GOA', language: 'vala')
endif

valadoc = find_program('valadoc', required: get_option('docs'))
blueprint_compiler = find_program('blueprint-compiler')


# Configuration
conf = configuration_data()
conf.set_quoted('APP_ID', contacts_app_id)
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('G_LOG_DOMAIN', meson.project_name())
conf.set_quoted('LOCALEDIR', locale_dir)
conf.set_quoted('LIBEXECDIR', get_option('prefix') / get_option('libexecdir'))
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_STRING', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('PROFILE', get_option('profile'))
conf.set('GOA_API_IS_SUBJECT_TO_CHANGE', true)
configure_file(output: 'config.h', configuration: conf)

# Subfolders
subdir('data')
subdir('po')
subdir('src')
if get_option('docs')
  subdir('docs')
endif
subdir('tests')

gnome.post_install(
  gtk_update_icon_cache: true,
  glib_compile_schemas: true,
  update_desktop_database: true,
)
