///|
test "decode pkix reads an RFC 7468 certificate" {
  // crypt-test.r3, Textual Encoding of Certificates.
  let env = @eval.Env::new()
  let source = "pem: {Subject: CN=Atlantis\nIssuer: CN=Atlantis\nValidity: from 7/9/2012 3:10:38 AM UTC to 7/9/2013 3:10:37 AM UTC\n-----BEGIN CERTIFICATE-----\nMIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz\nMB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs\nYW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh\nRyn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID\nAQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB\ngjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE\nLjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow\nCQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0\nILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=\n-----END CERTIFICATE-----}\ngot: decode 'pkix pem\nbin: decode/binary 'pkix pem\n"
  assert_true(
    @eval.run(
      env,
      source +
      "(reduce [type? got type? bin select got 'label]) = reduce [block! binary! {CERTIFICATE}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, source + "(select got 'binary) = bin") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, source + "(select got 'header) = []") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, source + "(select got 'post-text) = {}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env,
      source +
      "(select got 'pre-text) = {Subject: CN=Atlantis\nIssuer: CN=Atlantis\nValidity: from 7/9/2012 3:10:38 AM UTC to 7/9/2013 3:10:37 AM UTC}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env,
      source +
      "(checksum bin 'sha256) = #{91648283064E3E597FB5E720A2C07E478AB9B80FBAB0508FEC043834CD516986}",
    )
    is @value.Logic(true),
  )
}

///|
test "decode pkix keeps a header and joins a continued line" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "pem: {---- BEGIN SSH2 PUBLIC KEY ----\nComment: \"hello \\\nworld\"\nAAAA\n---- END SSH2 PUBLIC KEY ----}\ngot: decode 'pkix pem\n(reduce [select got 'label select got 'header select got 'binary]) = reduce [{SSH2 PUBLIC KEY} [{Comment} {hello world}] #{000000}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "none? decode 'pkix {not armor}") is @value.Logic(true),
  )
  let missing = try {
    @eval.run(env, "decode 'jpeg {x}") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "access"
        _ => false
      }
  }
  assert_true(missing)
}
