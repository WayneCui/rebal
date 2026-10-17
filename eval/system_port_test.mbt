///|
test "system port reads an empty wake list" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "p: open make port! [scheme: 'system] (read p) = []")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(query p)/type = 'system") is @value.Logic(true))
  assert_true(@eval.run(env, "(read system://) = []") is @value.Logic(true))
  assert_true(@eval.run(env, "close p (type? p) = port!") is @value.Logic(true))
  let shut = try {
    @eval.run(env, "read p") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(shut)
  let wrote = try {
    @eval.run(env, "write system:// 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(wrote)
}
