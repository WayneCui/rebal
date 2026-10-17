///|
test "series navigation is one-based and poke writes through the shared buffer" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "s: [1 2 3] index? next s") is @value.Integer(2L))
  assert_true(@eval.run(env, "first at s 2") is @value.Integer(2L))
  assert_true(@eval.run(env, "poke s 1 9 first s") is @value.Integer(9L))
  assert_true(@eval.run(env, "head? head s") is @value.Logic(true))
  assert_true(@eval.run(env, "tail? tail s") is @value.Logic(true))
  assert_true(@eval.run(env, "first back next s") is @value.Integer(9L))
}
