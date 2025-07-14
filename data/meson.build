# The resources (NOTE: needed by e.g. src/)
blueprints = custom_target(
  input: files(
    'ui/contacts-shortcuts-dialog.blp',
    'ui/contacts-avatar-selector.blp',
    'ui/contacts-birthday-editor.blp',
    'ui/contacts-contact-pane.blp',
    'ui/contacts-contact-sheet-row.blp',
    'ui/contacts-crop-dialog.blp',
    'ui/contacts-editable-avatar.blp',
    'ui/contacts-import-dialog.blp',
    'ui/contacts-link-suggestion-grid.blp',
    'ui/contacts-main-window.blp',
    'ui/contacts-preferences-window.blp',
    'ui/contacts-qr-code-dialog.blp',
    'ui/contacts-setup-window.blp',
  ),
  output: '.',
  command: [
    blueprint_compiler, 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@',
  ],
)

resource_files = files('contacts.gresource.xml')
resources = gnome.compile_resources('org.gnome.Contacts', resource_files,
  c_name: 'resources',
  source_dir: meson.current_build_dir(),
  dependencies: blueprints,
)

# The icons
iconsdir = get_option('datadir') / 'icons' / 'hicolor'
foreach size: ['scalable', 'symbolic']
  install_subdir('icons/hicolor/' + size, install_dir: iconsdir)
endforeach

# The desktop file
desktop_file = i18n.merge_file(
  input: configure_file(
    input: 'org.gnome.Contacts.desktop.in.in',
    output: '@BASENAME@',
    configuration: {
      'icon': contacts_app_id,
    },
  ),
  output: '@0@.desktop'.format(contacts_app_id),
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
    ],
    depends: [
      desktop_file,
    ],
  )
endif

# The appdata file
appdata_file = i18n.merge_file(
  input: configure_file(
    input: 'org.gnome.Contacts.metainfo.xml.in.in',
    output: '@BASENAME@',
    configuration: {
      'app_id': contacts_app_id,
    },
  ),
  output: '@0@.metainfo.xml'.format(contacts_app_id),
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: get_option('datadir') / 'metainfo',
)
# Validate the appdata file
appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test('validate-appdata', appstreamcli,
    suite: 'data',
    args: [
      'validate', '--no-net', '--explain', appdata_file.full_path()
    ],
    depends: [
      appdata_file,
    ],
  )
endif

# DBus service files
service_config = {
  'app_id': contacts_app_id,
  'bindir': contacts_prefix / get_option('bindir'),
  'libexecdir': contacts_prefix / get_option('libexecdir'),
}

# The DBUS service file of the app
configure_file(
  input: 'org.gnome.Contacts.service.in',
  output: '@0@.service'.format(contacts_app_id),
  configuration: service_config,
  install: true,
  install_dir: get_option('datadir') / 'dbus-1' / 'services',
)

# The DBUS service file of the search provider
configure_file(
  input: 'org.gnome.Contacts.SearchProvider.service.in',
  output: '@0@.SearchProvider.service'.format(contacts_app_id),
  configuration: service_config,
  install: true,
  install_dir: get_option('datadir') / 'dbus-1' / 'services',
)

# The search provider file
configure_file(
  input: 'org.gnome.Contacts.search-provider.ini.in',
  output: '@0@.search-provider.ini'.format(contacts_app_id),
  configuration: {
    'app_id': contacts_app_id,
  },
  install: true,
  install_dir: get_option('datadir') / 'gnome-shell' / 'search-providers',
)

# Manpage
if get_option('manpage')
  xsltproc = find_program('xsltproc')

  custom_target('manfile-gnome-contacts',
    input: 'gnome-contacts.xml',
    output: 'gnome-contacts.1',
    install: true,
    install_dir: get_option('mandir') / 'man1',
    command: [
      xsltproc,
      '--nonet',
      '--stringparam', 'man.output.quietly', '1',
      '--stringparam', 'funcsynopsis.style', 'ansi',
      '--stringparam', 'man.th.extra1.suppress', '1',
      '--stringparam', 'man.authors.section.enabled', '0',
      '--stringparam', 'man.copyright.section.enabled', '0',
      '-o', '@OUTPUT@',
      'http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl',
      '@INPUT@'
    ]
  )
endif
