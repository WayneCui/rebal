///|
test "sign, sum, and average reduce a block of numbers" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(sign? 1.5) = 1") is @value.Logic(true))
  assert_true(@eval.run(env, "(sign? -2) = -1") is @value.Logic(true))
  assert_true(@eval.run(env, "(sign? 0) = 0") is @value.Logic(true))
  assert_true(@eval.run(env, "(sum [1 2 3]) = 6") is @value.Logic(true))
  assert_true(@eval.run(env, "(sum []) = 0") is @value.Logic(true))
  assert_true(@eval.run(env, "(average [1 2 3]) = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "(average [1 2]) = 1.5") is @value.Logic(true))
  assert_true(@eval.run(env, "(average []) = none") is @value.Logic(true))
  assert_true(@eval.run(env, "(square-root 4) = 2.0") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(square-root 2.0) > 1.4") is @value.Logic(true),
  )
}
