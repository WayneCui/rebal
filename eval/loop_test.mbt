///|
test "while until and loop repeat until they stop" {
  // n-loop.c while, until, loop
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "n: 0 while [n < 3] [n: n + 1] n") is @value.Integer(3L),
  )
  assert_true(@eval.run(env, "while [false] [1]") is @value.None)
  assert_true(
    @eval.run(env, "n: 0 until [n: n + 1 n > 2]") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "loop 0 [1]") is @value.None)
  assert_true(@eval.run(env, "n: 0 loop 3 [n: n + 1] n") is @value.Integer(3L))
}

///|
test "break leaves the innermost loop and return leaves the function" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "f: func [] [n: 0 while [true] [n: n + 1 if n > 1 [break]] n] f",
    )
    is @value.Integer(2L),
  )
  assert_true(
    @eval.run(env, "g: func [] [while [true] [try [break] 1] 2] g")
    is @value.Integer(2L),
  )
  assert_true(
    @eval.run(env, "h: func [] [while [true] [return 4] 5] h")
    is @value.Integer(4L),
  )
  let escaped = try {
    @eval.run(@eval.Env::new(), "break") |> ignore
    false
  } catch {
    error => error.id() == "break"
  }
  assert_true(escaped)
}
