///|
test "decode der reads a definite-length value" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(decode 'der #{3003020101}) = [sequence [integer #{01}]]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'der #{3000}) = [sequence []]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decode 'der #{30820003020101}) = [sequence [integer #{01}]]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decode 'der #{30083003020101020102}) = [sequence [sequence [integer #{01}] integer #{02}]]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'der #{A003020102}) = [cs0 [integer #{02}]]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decode 'der #{300713054162633132}) = [sequence [printable_string {Abc12}]]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decode 'der #{300F170D3132303730393033313033385A}) = [sequence [utc_time 9-Jul-2012/3:10:38]]",
    )
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "none? decode 'der #{30}") is @value.Logic(true))
}

///|
test "decode der reads the Atlantis certificate name and validity" {
  // crypt-test.r3 certificate, then the DER inside it.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "bin: decode/binary 'pkix {-----BEGIN CERTIFICATE-----\nMIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz\nMB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs\nYW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh\nRyn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID\nAQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB\ngjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE\nLjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow\nCQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0\nILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=\n-----END CERTIFICATE-----}\ngot: decode 'der bin\ncert: pick got 2\ntbs: pick cert 2\nvalidity: pick tbs 10\nname: pick tbs 8\nname: pick name 2\nname: pick name 2\n(reduce [pick tbs 4 pick validity 2 pick validity 4 pick name 4]) = reduce [#{2A} 9-Jul-2012/3:10:38 9-Jul-2013/3:10:37 {Atlantis}]",
    )
    is @value.Logic(true),
  )
}
