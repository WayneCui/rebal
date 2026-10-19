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
test "foreach binds one word and continue skips one step" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "x: 0 foreach 'n [1 2 3] [x: x + n] x") is @value.Integer(6L),
  )
  assert_true(
    @eval.run(env, "x: 0 foreach 'n [1 2 3] [if n = 2 [continue] x: x + n] x")
    is @value.Integer(4L),
  )
  assert_true(
    @eval.run(env, "foreach 'n [1 2 3] [if n = 2 [break]]") is @value.None,
  )
  let escaped = try {
    @eval.run(@eval.Env::new(), "continue") |> ignore
    false
  } catch {
    error => error.id() == "continue"
  }
  assert_true(escaped)
}

///|
test "foreach walks groups, map keys, and map pairs" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "x: copy [] foreach [a b] [1 2 3 4] [append x a append x b] x = [1 2 3 4]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "x: copy [] foreach [a b] [1 2 3] [append x b] x = reduce [2 none]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "x: copy [] foreach k make map! [a: 1 b: 2] [append x k] x = [a b]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "x: copy [] foreach [k v] make map! [a: 1 b: 2] [append x k append x v] x = [a 1 b 2]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "x: 0 foreach [k v] make map! [a: 1 b: 2] [if k = 'a [continue] x: x + v] x = 2",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "foreach [k v] make map! [a: 1] [break]") is @value.None,
  )
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
