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
