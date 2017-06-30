project('gnome-contacts', [ 'vala', 'c' ],
  version: '3.22.1',
  license: 'GPL2+',
  meson_version: '>= 0.37',
)

gnome = import('gnome')
i18n = import('i18n')

# Add our custom VAPI dir
add_project_arguments(
  ['--vapidir', join_paths(meson.source_root(), 'vapi')],
  language: 'vala'
)

# Some variables
config_h_dir = include_directories('.')
locale_dir = join_paths(get_option('prefix'), get_option('localedir'))
pkgdatadir = join_paths(get_option('datadir'), meson.project_name())
pkglibdir = join_paths(get_option('libdir'), meson.project_name())
po_dir = join_paths(meson.source_root(), 'po')

# Dependencies
champlain = dependency('champlain-0.12')
clutter_gtk = dependency('clutter-gtk-1.0')
folks = dependency('folks', version: '>= 0.9.5')
folks_eds = dependency('folks-eds')
folks_telepathy = dependency('folks-telepathy')
gee = dependency('gee-0.8')
geocode_glib = dependency('geocode-glib-1.0', version: '>= 3.15.3')
gio_unix = dependency('gio-unix-2.0')
glib = dependency('glib-2.0', version: '>= 2.44.0')
gmodule_export = dependency('gmodule-export-2.0')
gnome_desktop = dependency('gnome-desktop-3.0')
goa = dependency('goa-1.0')
gtk = dependency('gtk+-3.0', version: '>= 3.22.0')
libebook = dependency('libebook-1.2', version: '>= 3.13.90')
libedataserver = dependency('libedataserver-1.2', version: '>= 3.13.90')
telepathy_glib = dependency('telepathy-glib', version: '>= 0.22.0')

if get_option('with-cheese')
  cheese = dependency('cheese')
  cheese_gtk = dependency('cheese-gtk', version: '>= 3.3.91')
endif

# Libraries
cc = meson.get_compiler('c')
libedataserverui = cc.find_library('libedataserverui-1.2', version: '>= 3.13.90')
math = cc.find_library('m')

# Configuration
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', locale_dir)
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_STRING', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('PKGDATADIR', pkgdatadir)
conf.set_quoted('PKGLIBDIR', pkglibdir)
conf.set_quoted('VERSION', meson.project_version())
configure_file(output: 'config.h', configuration: conf)

subdir('data')
subdir('po')
subdir('src')
subdir('man')
