project('gnome-contacts', [ 'vala', 'c' ],
  version: '42.alpha',
  meson_version: '>= 0.50',
  license: 'GPL-2.0-or-later',
)

gnome = import('gnome')
i18n = import('i18n')

# Add our custom VAPI dir
add_project_arguments(
  ['--vapidir', meson.source_root() / 'vapi'],
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
po_dir = meson.source_root() / 'po'

# Dependencies
min_eds_version = '3.30'
min_folks_version = '0.14'
min_glib_version = '2.58' # We also use this value for --target-glib, so scratch the micro version.

# We know that compiling on a lower version doesn't work
min_vala_version = '0.40.10'
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
# gnome_desktop = dependency('gnome-desktop-3.0')
goa = dependency('goa-1.0')
gtk4_dep = dependency('gtk4', version: '>= 4.6')
libadwaita_dep = dependency('libadwaita-1')
# E-D-S
libebook = dependency('libebook-1.2', version: '>=' + min_eds_version)
libedataserver = dependency('libedataserver-1.2', version: '>=' + min_eds_version)
# libedataserverui = dependency('libedataserverui-1.2', version: '>=' + min_eds_version)
# Portals (needed for camera access)
libportal_dep = dependency('libportal', version: '>= 0.5')
# Cheese
# cheese_dep = dependency('cheese', required: get_option('cheese'))
# cheese_gtk_dep = dependency('cheese-gtk', version: '>= 3.3.91', required: get_option('cheese'))

if get_option('telepathy')
  folks_telepathy = dependency('folks-telepathy', version: '>=' + min_folks_version)
  telepathy_glib = dependency('telepathy-glib', version: '>= 0.22.0')
endif

valadoc = find_program('valadoc', required: get_option('docs'))


# Configuration
conf = configuration_data()
conf.set_quoted('APP_ID', contacts_app_id)
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('G_LOG_DOMAIN', meson.project_name())
conf.set_quoted('LOCALEDIR', locale_dir)
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_STRING', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('PROFILE', get_option('profile'))
conf.set('GOA_API_IS_SUBJECT_TO_CHANGE', true)
configure_file(output: 'config.h', configuration: conf)

# Post-install scripts
meson.add_install_script('build-aux/meson_post_install.py')

# Subfolders
subdir('data')
subdir('po')
subdir('src')
if get_option('docs')
  subdir('docs')
endif
subdir('tests')
