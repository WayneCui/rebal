///|
test "case takes the first truthy condition and switch matches with equal" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "case [false [1] true [2]]") is @value.Integer(2L))
  assert_true(@eval.run(env, "case [false 1 true 2]") is @value.Integer(2L))
  assert_true(
    @eval.run(env, "case [1 < 0 [1] 1 > 0 [2]]") is @value.Integer(2L),
  )
  assert_true(@eval.run(env, "case [false [1]]") is @value.None)
  assert_true(@eval.run(env, "switch 2 [1 [10] 2 [20]]") is @value.Integer(20L))
  assert_true(@eval.run(env, "switch 2 [1 10 2 20]") is @value.Integer(20L))
  assert_true(@eval.run(env, "switch 3 [1 [1]]") is @value.None)
  assert_true(@eval.run(env, "1 == 1.0") is @value.Logic(false))
  assert_true(@eval.run(env, "1 <= 1.0") is @value.Logic(true))
}
