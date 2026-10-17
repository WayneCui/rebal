///|
test "get set and unset address a word" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "a: 1 get 'a") is @value.Integer(1L))
  assert_true(@eval.run(env, "set 'b 2 b") is @value.Integer(2L))
  assert_true(@eval.run(env, "unset 'b") is @value.Unset)
  assert_true(@eval.run(env, "unset? 'b") is @value.Logic(true))
  assert_true(@eval.run(env, "value? 'a") is @value.Logic(true))
  assert_true(@eval.run(env, "unset? 'missing") is @value.Logic(true))
  assert_true(
    @eval.run(env, "o: make object! [a: 4] in o 'a") is @value.Integer(4L),
  )
}
