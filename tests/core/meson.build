test_names = [
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
