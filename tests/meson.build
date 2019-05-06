test_names = [
  'basic-test',
]

foreach _test : test_names
  test_bin = executable(_test,
    '@0@.vala'.format(_test),
    dependencies: libcontacts_dep,
  )

  test(_test, test_bin,
    suite: 'gnome-contacts',
  )
endforeach
