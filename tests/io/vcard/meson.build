io_vcard_files = [
  'minimal',
]

foreach vcard_name : io_vcard_files
  vcf_file = meson.current_source_dir() / vcard_name + '.vcf'

  # Ideally we'd do this using a preprocessor symbol or something
  vcf_test_env = environment()
  vcf_test_env.append('_VCF_FILE', vcf_file)

  test_bin = executable(vcard_name,
    files('test-vcard-'+vcard_name+'.vala'),
    dependencies: libcontacts_dep,
  )

  test(vcard_name, test_bin,
    suite: 'io-vcard',
    env: vcf_test_env,
  )
endforeach
