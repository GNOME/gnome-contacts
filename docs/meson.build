docs_vapidirs = [
  '--vapidir=@0@'.format(meson.project_source_root() / 'vapi'),
]

docs_sources = [
  libcontactscore_sources,
  libcontacts_sources,
  contacts_io_sources,
  contacts_vala_sources,
]

custom_target('docs',
  input: docs_sources,
  output: 'docs',
  command: [ valadoc,
    '--doclet=html',
    '--force',
    '--package-name=@0@'.format(meson.project_name()),
    '--package-version=@0@'.format(meson.project_version()),
    '--pkg=glib-2.0',
    '--pkg=gio-2.0',
    '--pkg=gio-unix-2.0',
    '--pkg=gtk4',
    '--pkg=libportal-gtk4',
    '--pkg=gee-0.8',
    '--pkg=goa-1.0',
    '--pkg=folks',
    '--pkg=folks-eds',
    '--pkg=libadwaita-1',
    '--pkg=libqrencode',
    '--pkg=custom',
    '--pkg=config',
    '--directory=@OUTDIR@',
    docs_vapidirs,
    docs_sources,
  ],
  build_by_default: true,
)
