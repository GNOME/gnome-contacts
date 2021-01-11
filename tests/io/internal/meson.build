io_internal_testlib = library('io-internal-testlib',
  files('test-serialise-common.vala'),
  dependencies: libcontacts_dep,
)

io_internal_testlib_dep = declare_dependency(
  link_with: io_internal_testlib,
  include_directories: include_directories('.'),
)

io_internal_test_names = [
  'serialise-full-name',
  'serialise-structured-name',
  'serialise-nickname',
  'serialise-birthday',
  'serialise-emails',
  'serialise-urls',
]

foreach _test : io_internal_test_names
  test_bin = executable(_test,
    files('test-'+_test+'.vala'),
    dependencies: [ libcontacts_dep, io_internal_testlib_dep ],
  )

  test(_test, test_bin,
    suite: 'io-internal',
  )
endforeach
