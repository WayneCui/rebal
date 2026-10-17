///|
test "any and all stop early and and still evaluates its right side" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "any [none false 3]") is @value.Integer(3L))
  assert_true(@eval.run(env, "any [none]") is @value.None)
  assert_true(@eval.run(env, "all [1 2 3]") is @value.Integer(3L))
  assert_true(@eval.run(env, "all [1 false 3]") is @value.None)
  assert_true(@eval.run(env, "all [1 () 2]") is @value.Integer(2L))
  assert_true(@eval.run(env, "n: 0 false and (n: 1) n") is @value.Integer(1L))
  assert_true(@eval.run(env, "not none") is @value.Logic(true))
}
