///|
test "decode crt reads the Atlantis certificate fields" {
  // crypt-test.r3 certificate. The modulus keeps the INTEGER sign byte.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "cert: decode 'crt {-----BEGIN CERTIFICATE-----\nMIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz\nMB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs\nYW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh\nRyn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID\nAQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB\ngjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE\nLjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow\nCQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0\nILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=\n-----END CERTIFICATE-----}\nkey: cert/public-key/rsaEncryption\n(reduce [type? cert cert/version cert/serial-number cert/algorithm cert/issuer/commonName cert/valid-from cert/valid-to cert/subject/commonName key/1 key/2 length? cert/signature]) = reduce [object! 2 #{2A} 'sha1WithRSAEncryption {Atlantis} 9-Jul-2012/3:10:38 9-Jul-2013/3:10:37 {Atlantis} #{00BBE057A3E9A269B0C81C7C7ECAABAACEA3614729FF5ED9092081D5718B47BC85FE4B5C7912B80CA077A1C9CA68C5B12B666551E060AAD52D9D88D991159091B5} #{010001} 65]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "blank: decode 'crt #{00}\nnone? blank/version")
    is @value.Logic(true),
  )
}
