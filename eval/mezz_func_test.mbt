///|
test "closure locals stay inside, clos writes out, has and map build values" {
  let env = @eval.Env::new()
  @eval.run(env, "a: 0") |> ignore
  assert_true(
    @eval.run(env, "c: closure [] [a: 4 a] (c) = 4") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "a = 0") is @value.Logic(true))
  assert_true(
    @eval.run(env, "k: clos [] [a: 7 a] (k) = 7") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "a = 7") is @value.Logic(true))
  @eval.run(env, "n: 0") |> ignore
  assert_true(
    @eval.run(env, "h: has [n] [n: 5 n] (h) = 5") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "n = 0") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(select map [a 1 b 2] 'b) = 2") is @value.Logic(true),
  )
}
