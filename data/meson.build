# The resources (NOTE: needed by e.g. src/)
resource_files = files('contacts.gresource.xml')
resources = gnome.compile_resources('org.gnome.Contacts', resource_files,
  c_name: 'resources'
)

# The icons
iconsdir = join_paths(get_option('datadir'), 'icons', 'hicolor')
foreach size: ['16x16', '22x22', '32x32', '48x48', '512x512', 'symbolic']
  install_subdir('icons/hicolor/' + size, install_dir: iconsdir)
endforeach

# The desktop file
i18n.merge_file(
  input: 'org.gnome.Contacts.desktop.in',
  output: 'org.gnome.Contacts.desktop',
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

# The appdata file
i18n.merge_file(
  input: 'org.gnome.Contacts.appdata.xml.in',
  output: 'org.gnome.Contacts.appdata.xml',
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# DBus service files
service_config = configuration_data()
service_config.set('bindir', join_paths(get_option('prefix'), get_option('bindir')))
service_config.set('libexecdir', join_paths(get_option('prefix'), get_option('libexecdir')))

# The DBUS service file of the app
configure_file(
  input: 'org.gnome.Contacts.service.in',
  output: 'org.gnome.Contacts.service',
  configuration: service_config,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services'),
)

# The DBUS service file of the search provider
configure_file(
  input: 'org.gnome.Contacts.SearchProvider.service.in',
  output: 'org.gnome.Contacts.SearchProvider.service',
  configuration: service_config,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services'),
)
