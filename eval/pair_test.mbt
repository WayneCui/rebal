///|
test "pair scans, molds, converts, and combines" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(mold 3x4) = {3x4}") is @value.Logic(true))
  assert_true(@eval.run(env, "3x4 = make pair! [3 4]") is @value.Logic(true))
  assert_true(@eval.run(env, "(make pair! 10) = 10x10") is @value.Logic(true))
  assert_true(@eval.run(env, "3x4 + 1x1 = 4x5") is @value.Logic(true))
  assert_true(@eval.run(env, "3x4 + 1 = 4x5") is @value.Logic(true))
  assert_true(@eval.run(env, "3x4 * 2 = 6x8") is @value.Logic(true))
  assert_true(@eval.run(env, "(first 3x4) = 3") is @value.Logic(true))
  assert_true(@eval.run(env, "(pick 3x4 2) = 4") is @value.Logic(true))
  assert_true(@eval.run(env, "p: 3x4 p/x = 3") is @value.Logic(true))
  assert_true(@eval.run(env, "p: 3x4 p/y = 4") is @value.Logic(true))
}
