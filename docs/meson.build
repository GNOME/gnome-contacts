docs_vapidirs = [
  '--vapidir=@0@'.format(join_paths(meson.source_root(), 'vapi')),
]

if libhandy_vapidir != ''
  docs_vapidirs += '--vapidir=@0@'.format(libhandy_vapidir )
endif

custom_target('docs',
  input: contacts_vala_sources,
  output: 'docs',
  command: [ valadoc,
    '--doclet=html',
    '--force',
    '--package-name=@0@'.format(meson.project_name()),
    '--package-version=@0@'.format(meson.project_version()),
    '--pkg=glib-2.0',
    '--pkg=gio-2.0',
    '--pkg=gio-unix-2.0',
    '--pkg=gtk+-3.0',
    '--pkg=gnome-desktop-3.0',
    '--pkg=gee-0.8',
    '--pkg=goa-1.0',
    '--pkg=folks',
    '--pkg=folks-eds',
    '--pkg=libedataserverui-1.2',
    '--pkg=libhandy-0.0',
    '--pkg=custom',
    '--pkg=config',
    '--directory=@OUTDIR@',
    docs_vapidirs,
    [ libcontacts_sources, contacts_vala_sources ],
  ],
  build_by_default: true,
)
