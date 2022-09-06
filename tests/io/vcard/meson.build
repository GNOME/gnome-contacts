io_vcard_files = [
  'minimal',
]

test_deps = [
  gee,
  folks,
  libebook,
  libcontactscore_dep,
]

foreach vcard_name : io_vcard_files
  vcf_file = meson.current_source_dir() / vcard_name + '.vcf'

  # Ideally we'd do this using a preprocessor symbol or something
  vcf_test_env = environment()
  vcf_test_env.append('_VCF_FILE', vcf_file)

  test_sources = [
    contacts_io_sources,
    'test-vcard-'+vcard_name+'-import.vala',
  ]

  test_bin = executable(vcard_name,
    test_sources,
    dependencies: test_deps,
  )

  test(vcard_name, test_bin,
    suite: 'io-vcard',
    env: vcf_test_env,
  )
endforeach
