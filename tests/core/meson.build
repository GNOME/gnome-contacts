test_names = [
  'test-addresses-chunk',
  'test-birthday-chunk',
  'test-email-addresses-chunk',
  'test-full-name-chunk',
  'test-nickname-chunk',
  'test-notes-chunk',
  'test-phones-chunk',
  'test-roles-chunk',
  'test-structured-name-chunk',
  'test-urls-chunk',
]

foreach _test : test_names
  test_bin = executable(_test,
    files('@0@.vala'.format(_test)),
    dependencies: libcontactscore_dep,
  )

  test(_test, test_bin,
    suite: 'core',
  )
endforeach
