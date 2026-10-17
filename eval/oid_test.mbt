///|
test "decode oid names a known arc and spells the rest" {
  // codecs-test.r3 form-OID and decode-OID, plus the numeric fallback.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(decode 'oid #{551D11}) = 'subjectAltName")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold decode 'oid #{551D11}) = {subjectAltName}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'oid #{2A8648CE3D040302}) = 'ecdsa-with-SHA256")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(mold decode 'oid #{2A8648CE3D040302}) = {ecdsa-with-SHA256}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'oid #{2A8648CE3D040309}) = {1.2.840.10045.4.3.9}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'oid #{2A03}) = {1.2.3}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'oid #{550403}) = 'commonName")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'oid #{2B0E03021D}) = 'sha1WithRSAEncryption")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'oid #{551D11FF}) = 'subjectAltName")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'oid #{2A81}) = {1.2}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decode 'oid #{551D63}) = {2.5.29.99}")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "none? decode 'oid #{}") is @value.Logic(true))
}
