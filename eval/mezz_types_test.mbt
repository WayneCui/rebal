///|
test "to-integer and the other to-* words call to" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(to-integer 1:0:0) = 3600") is @value.Logic(true))
  assert_true(@eval.run(env, "(to-decimal 1%) = 0.01") is @value.Logic(true))
  assert_true(@eval.run(env, "(to-percent 1) = 100%") is @value.Logic(true))
  assert_true(@eval.run(env, "(to-pair 3) = 3x3") is @value.Logic(true))
}
