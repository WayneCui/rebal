///|
test "print forms values and prin stays on the same line" {
  let env = @eval.Env::new()
  let before = @eval.console_written()
  assert_true(@eval.run(env, "print 1") is @value.Unset)
  assert_true(@eval.run(env, "print {ab}") is @value.Unset)
  assert_true(@eval.run(env, "print [1 + 2 {x}]") is @value.Unset)
  assert_true(@eval.run(env, "prin 4") is @value.Unset)
  assert_true(@eval.run(env, "print none") is @value.Unset)
  assert_true(@eval.run(env, "print #\"a\"") is @value.Unset)
  assert_true(@eval.run(env, "print ()") is @value.Unset)
  assert_true(@eval.run(env, "print [1 () 2]") is @value.Unset)
  assert_eq(@eval.console_written(), before + "1\nab\n3 x\n4none\na\n\n1  2\n")
}

///|
test "print reduces a block from its index and leaves the block unchanged" {
  let env = @eval.Env::new()
  let before = @eval.console_written()
  assert_true(
    @eval.run(env, "b: [1 + 2] print b b = [1 + 2]") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "print next [10 1 + 2]") is @value.Unset)
  assert_true(@eval.run(env, "print first [(1 + 2)]") is @value.Unset)
  assert_eq(@eval.console_written(), before + "3\n3\n1 + 2\n")
}

///|
test "print reports a missing word and rejects a refinement" {
  let env = @eval.Env::new()
  let before = @eval.console_written()
  let missing = try {
    @eval.run(env, "print [nope]") |> ignore
    false
  } catch {
    error => error.id() == "no-value"
  }
  assert_true(missing)
  assert_eq(@eval.console_written(), before)
  let bare = try {
    @eval.run(env, "print") |> ignore
    false
  } catch {
    error => error.id() == "missing-arg"
  }
  assert_true(bare)
  let refined = try {
    @eval.run(env, "print/only 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(refined)
  assert_eq(@eval.console_written(), before)
}
