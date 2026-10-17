///|
test "protect blocks a later assignment" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "n: 1 protect 'n (protected? 'n) = true")
    is @value.Logic(true),
  )
  let blocked = try {
    @eval.run(env, "n: 2") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(blocked)
  assert_true(@eval.run(env, "n = 1") is @value.Logic(true))
  assert_true(
    @eval.run(env, "unprotect 'n n: 3 (protected? 'n) = false")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "n = 3") is @value.Logic(true))
}
