///|
test "decode utc-time reads an ASN.1 UTCTime" {
  // crypt-test.r3, Basic UTC-time decoding.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(mold decode 'utc-time {120709031038Z}) = {9-Jul-2012/3:10:38}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(mold decode 'utc-time #{3132303730393033313033385A}) = {9-Jul-2012/3:10:38}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold decode 'utc-time {1207090310Z}) = {9-Jul-2012/3:10}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(mold decode 'utc-time {1207090310+0200}) = {9-Jul-2012/3:10+2:00}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "none? decode 'utc-time {not-a-time}") is @value.Logic(true),
  )
}
