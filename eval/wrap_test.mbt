///|
test "wrap keeps set-words local after they are seen" {
  let env = @eval.Env::new()
  @eval.run(env, "a: 9") |> ignore
  assert_true(@eval.run(env, "(wrap [a: 4 a]) = 4") is @value.Logic(true))
  assert_true(@eval.run(env, "a = 9") is @value.Logic(true))
  assert_true(@eval.run(env, "(wrap [a]) = 9") is @value.Logic(true))
  assert_true(@eval.run(env, "(wrap [b: a a: 1 b]) = 9") is @value.Logic(true))
  assert_true(@eval.run(env, "a = 9") is @value.Logic(true))
}
