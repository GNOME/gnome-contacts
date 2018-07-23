# The resources (NOTE: needed by e.g. src/)
resource_files = files('contacts.gresource.xml')
resources = gnome.compile_resources('org.gnome.Contacts', resource_files,
  c_name: 'resources'
)

# The icons
iconsdir = join_paths(datadir, 'icons', 'hicolor')
foreach size: ['scalable', 'symbolic']
  install_subdir('icons/hicolor/' + size, install_dir: iconsdir)
endforeach

# The desktop file
i18n.merge_file(
  input: 'org.gnome.Contacts.desktop.in',
  output: 'org.gnome.Contacts.desktop',
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'applications')
)

# The appdata file
i18n.merge_file(
  input: 'org.gnome.Contacts.appdata.xml.in',
  output: 'org.gnome.Contacts.appdata.xml',
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'metainfo')
)

# DBus service files
service_config = configuration_data()
service_config.set('bindir', join_paths(bindir))
service_config.set('libexecdir', join_paths(libexecdir))

# The DBUS service file of the app
configure_file(
  input: 'org.gnome.Contacts.service.in',
  output: 'org.gnome.Contacts.service',
  configuration: service_config,
  install: true,
  install_dir: join_paths(datadir, 'dbus-1', 'services'),
)

# The DBUS service file of the search provider
configure_file(
  input: 'org.gnome.Contacts.SearchProvider.service.in',
  output: 'org.gnome.Contacts.SearchProvider.service',
  configuration: service_config,
  install: true,
  install_dir: join_paths(datadir, 'dbus-1', 'services'),
)

# The search provider file
install_data('org.gnome.Contacts.search-provider.ini',
  install_dir: join_paths(datadir, 'gnome-shell', 'search-providers'),
)
