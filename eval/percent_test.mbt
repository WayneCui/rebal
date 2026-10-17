///|
test "percent scans, molds, converts, and combines" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(mold 1%) = {1%}") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold 0.1%) = {0.1%}") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold 100%) = {100%}") is @value.Logic(true))
  assert_true(@eval.run(env, "1% = 0.01") is @value.Logic(true))
  assert_true(@eval.run(env, "100% = make percent! 1") is @value.Logic(true))
  assert_true(@eval.run(env, "50% = make percent! 0.5") is @value.Logic(true))
  assert_true(@eval.run(env, "(to decimal! 1%) = 0.01") is @value.Logic(true))
  assert_true(@eval.run(env, "(to integer! 100%) = 1") is @value.Logic(true))
  assert_true(@eval.run(env, "50% + 50% = 100%") is @value.Logic(true))
  assert_true(@eval.run(env, "10 * 50% = 5") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(make percent! true) = 100%") is @value.Logic(true),
  )
}
