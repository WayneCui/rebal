///|
test "catch takes a matching throw and lets other exits pass" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "catch none [1]") is @value.Integer(1L))
  assert_true(@eval.run(env, "catch none [throw none 4]") is @value.Integer(4L))
  assert_true(@eval.run(env, "catch 'x [throw 'x 5]") is @value.Integer(5L))
  assert_true(
    @eval.run(env, "f: func [] [catch none [return 6] 7] f")
    is @value.Integer(6L),
  )
  let missed = try {
    @eval.run(@eval.Env::new(), "catch 'x [throw 'y 1]") |> ignore
    false
  } catch {
    error => error.id() == "throw"
  }
  assert_true(missed)
}
