io_vcard_tests = [
  'minimal',

  'bday',
  'email',
]

test_deps = [
  gee,
  folks,
  libebook,
  libcontactscore_dep,
]

foreach test_name : io_vcard_tests
  test_sources = [
    contacts_io_sources,
    'test-vcard-'+test_name+'.vala',
  ]

  test_bin = executable(test_name,
    test_sources,
    dependencies: test_deps,
  )

  test(test_name, test_bin,
    suite: 'vcard',
  )
endforeach
