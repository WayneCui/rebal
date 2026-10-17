///|
test "wait sleeps for a duration and returns none for a port" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(wait 0) = none") is @value.Logic(true))
  assert_true(@eval.run(env, "(wait 0.0) = none") is @value.Logic(true))
  assert_true(@eval.run(env, "(wait 0:00) = none") is @value.Logic(true))
  assert_true(@eval.run(env, "(wait 0.01) = none") is @value.Logic(true))
  assert_true(@eval.run(env, "(wait none) = none") is @value.Logic(true))
  assert_true(
    @eval.run(env, "p: open %/tmp/ (wait p) = none") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(wait compose [(p) 0]) = none") is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "wait -1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
