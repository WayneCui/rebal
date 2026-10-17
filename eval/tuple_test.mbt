///|
test "tuple scans, molds, converts, and combines" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(mold 1.2) = {1.2}") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold 1.2.3) = {1.2.3}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "1.2.3 = make tuple! [1 2 3]") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "1.2.3 + 1.0.1 = 2.2.4") is @value.Logic(true))
  assert_true(@eval.run(env, "(first 1.2.3) = 1") is @value.Logic(true))
  assert_true(@eval.run(env, "(pick 1.2.3 3) = 3") is @value.Logic(true))
}
