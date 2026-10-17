///|
test "http port reads a response body" {
  let env = @eval.Env::new()
  let number = @eval.http_serve()
  assert_true(number > 0)
  let source = "p: open http://127.0.0.1:" +
    number.to_string() +
    "/index (read p) = {ok}"
  assert_true(@eval.run(env, source) is @value.Logic(true))
  assert_true(
    @eval.run(env, "(query http://127.0.0.1/index)/type = 'http")
    is @value.Logic(true),
  )
  let refused = try {
    @eval.run(env, "read http://127.0.0.1:1/") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(refused)
}
