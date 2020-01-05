# The resources (NOTE: needed by e.g. src/)
resource_files = files('contacts.gresource.xml')
resources = gnome.compile_resources('org.gnome.Contacts', resource_files,
  c_name: 'resources'
)

# The icons
iconsdir = get_option('datadir') / 'icons' / 'hicolor'
foreach size: ['scalable', 'symbolic']
  install_subdir('icons/hicolor/' + size, install_dir: iconsdir)
endforeach

# The desktop file
desktop_file = i18n.merge_file(
  input: 'org.gnome.Contacts.desktop.in',
  output: '@BASENAME',
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: get_option('datadir') / 'applications'
)
# Validate the desktop file 
desktop_file_validate = find_program ('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test('validate-desktop',
    desktop_file_validate,
    suite: 'data',
    args: [
      desktop_file.full_path()
    ]
  )
endif

# The appdata file
appdata_file = i18n.merge_file(
  input: 'org.gnome.Contacts.appdata.xml.in',
  output: 'org.gnome.Contacts.appdata.xml',
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: get_option('datadir') / 'metainfo',
)
# Validate the appdata file 
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('validate-appdata', appstream_util,
    suite: 'data',
    args: [
      'validate-relax', '--nonet', appdata_file.full_path()
    ]
  )
endif

# DBus service files
service_config = configuration_data()
service_config.set('bindir', contacts_prefix / get_option('bindir'))
service_config.set('libexecdir', contacts_prefix / get_option('libexecdir'))

# The DBUS service file of the app
configure_file(
  input: 'org.gnome.Contacts.service.in',
  output: '@BASENAME@',
  configuration: service_config,
  install: true,
  install_dir: get_option('datadir') / 'dbus-1' / 'services',
)

# The DBUS service file of the search provider
configure_file(
  input: 'org.gnome.Contacts.SearchProvider.service.in',
  output: '@BASENAME@',
  configuration: service_config,
  install: true,
  install_dir: get_option('datadir') / 'dbus-1' / 'services',
)

# The search provider file
install_data('org.gnome.Contacts.search-provider.ini',
  install_dir: get_option('datadir') / 'gnome-shell' / 'search-providers',
)
