project('gnome-contacts', [ 'vala', 'c' ],
  version: '3.36.1',
  license: 'GPL2+',
  meson_version: '>= 0.50',
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
config_h_dir = include_directories('.')
contacts_prefix = get_option('prefix')
locale_dir = contacts_prefix / get_option('localedir')
po_dir = meson.source_root() / 'po'

# Dependencies
min_eds_version = '3.13.90'
min_folks_version = '0.11.4'
min_glib_version = '2.44' # We also use this value for --target-glib, so scratch the micro version.

math = meson.get_compiler('c').find_library('m')

folks = dependency('folks', version: '>=' + min_folks_version)
folks_eds = dependency('folks-eds', version: '>=' + min_folks_version)
gee = dependency('gee-0.8')
gio_unix = dependency('gio-unix-2.0', version: '>=' + min_glib_version)
glib = dependency('glib-2.0', version: '>=' + min_glib_version)
gmodule_export = dependency('gmodule-export-2.0', version: '>=' + min_glib_version)
gnome_desktop = dependency('gnome-desktop-3.0')
goa = dependency('goa-1.0')
gtk = dependency('gtk+-3.0', version: '>= 3.23.1')
libebook = dependency('libebook-1.2', version: '>=' + min_eds_version)
libedataserver = dependency('libedataserver-1.2', version: '>=' + min_eds_version)
libedataserverui = dependency('libedataserverui-1.2', version: '>=' + min_eds_version)

if get_option('cheese')
  cheese = dependency('cheese')
  cheese_gtk = dependency('cheese-gtk', version: '>= 3.3.91')
endif

if get_option('telepathy')
  folks_telepathy = dependency('folks-telepathy', version: '>=' + min_folks_version)
  telepathy_glib = dependency('telepathy-glib', version: '>= 0.22.0')
endif

libhandy = dependency('libhandy-0.0', version: '>= 0.0.12', required: false)
if not libhandy.found()
  libhandy_subproj = subproject(
    'libhandy',
    default_options: [
      'examples=false',
      'glade_catalog=disabled',
      'tests=false',
    ]
  )

  # When using libhandy as subproject, make sure we get the VAPI file
  libhandy = declare_dependency(
    dependencies: [
      libhandy_subproj.get_variable('libhandy_dep'),
      libhandy_subproj.get_variable('libhandy_vapi'),
    ]
  )

  libhandy_vapidir = meson.build_root() / 'subprojects' / 'libhandy' / 'src'
else
  libhandy_vapidir = ''
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
if get_option('manpage')
  subdir('man')
endif
if get_option('docs')
  subdir('docs')
endif
subdir('tests')
