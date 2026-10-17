///|
test "use keeps its words local and starts them at none" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(use [a b] [a: 1 b: 2 a + b]) = 3") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "use [a] [a = none]") is @value.Logic(true))
  assert_true(@eval.run(env, "a: 5 use [a] [a: 1] a = 5") is @value.Logic(true))
  assert_true(@eval.run(env, "(use 'a [a: 8 a]) = 8") is @value.Logic(true))
  assert_true(@eval.run(env, "a = 5") is @value.Logic(true))
  assert_true(
    @eval.run(env, "a: 0 code: [a: 4] use [a] code a = 0") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "do code a = 4") is @value.Logic(true))
  let bad = try {
    @eval.run(env, "use 1 [1]") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
