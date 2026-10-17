///|
test "if and either evaluate only the chosen branch" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "if false [1]") is @value.None)
  assert_true(@eval.run(env, "if 1 < 2 [3]") is @value.Integer(3L))
  assert_true(@eval.run(env, "if true 1") is @value.Integer(1L))
  assert_true(@eval.run(env, "if 0 [1]") is @value.Integer(1L))
  assert_true(@eval.run(env, "if [] [1]") is @value.Integer(1L))
  assert_true(@eval.run(env, "n: 0 if false [n: 1] n") is @value.Integer(0L))
  assert_true(@eval.run(env, "either false [1] [2]") is @value.Integer(2L))
  assert_true(@eval.run(env, "either true 1 [2]") is @value.Integer(1L))
  assert_true(@eval.run(env, "1 = 1.0") is @value.Logic(true))
  assert_true(@eval.run(env, "\"A\" = \"a\"") is @value.Logic(true))
  assert_true(@eval.run(env, "1 <> 2") is @value.Logic(true))
  let mismatched = try {
    @eval.run(env, "1 < 2 > 0") |> ignore
    false
  } catch {
    @eval.Cannot(text) => text == "compare"
    _ => false
  }
  assert_true(mismatched)
}

///|
test "return leaves only the current function" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "f: func [x] [if x < 2 [return 1] x] f 1")
    is @value.Integer(1L),
  )
  assert_true(@eval.run(env, "f 3") is @value.Integer(3L))
  assert_true(
    @eval.run(env, "g: func [] [try [return 4] 5] g") is @value.Integer(4L),
  )
  assert_true(
    @eval.run(env, "outer: func [] [inner: func [] [return 6] inner 7] outer")
    is @value.Integer(7L),
  )
  let escaped = try {
    @eval.run(@eval.Env::new(), "return 1") |> ignore
    false
  } catch {
    error => error.id() == "return"
  }
  assert_true(escaped)
}
