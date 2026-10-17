///|
test "do returns the last expression" {
  // evaluation-test.r3:17 do-1, :20 do-2, :23 do-3, :26 do-4, :33 do-6, :36 do-7, :45 do-10
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "123") is @value.Integer(123L))
  assert_true(@eval.run(env, "none") is @value.None)
  assert_true(@eval.run(env, "false") is @value.Logic(false))
  match @eval.run(env, "'z") {
    @value.Sym(datatype, lexeme) => {
      assert_true(datatype == @value.Word)
      assert_eq(lexeme.spelling(), "z")
    }
    _ => fail("lit-word")
  }
  assert_true(@eval.run(env, "1 + 2") is @value.Integer(3L))
  assert_true(@eval.run(env, "1 + 2 * 3") is @value.Integer(9L))
  assert_true(@eval.run(env, "1 + 2 3 + 4") is @value.Integer(7L))
  assert_true(@eval.run(env, "a: 1 + 2 a") is @value.Integer(3L))
  assert_true(@eval.run(env, "1") is @value.Integer(1L))
  assert_true(@eval.run(env, "(1 + 2) * 3") is @value.Integer(9L))
  // evaluation-test.r3:39 do-8, :42 do-9
  assert_true(
    @eval.run(env, "1 + length? mold append [1] #\"t\"") is @value.Integer(9L),
  )
  let typed = @eval.run(env, "type? first [a]")
  assert_true(typed.equal(@eval.run(env, "word!")))
  assert_true(@eval.run(env, "1 + length? [1 2]") is @value.Integer(3L))
  assert_true(@eval.run(env, "length? append [1] 2") is @value.Integer(2L))
  match @eval.run(env, "first [[a]]") {
    @value.Seq(block, _) => assert_eq(block.length(), 1)
    _ => fail("data block")
  }
}

///|
test "do/next advances the same series" {
  // evaluation-test.r3:73
  let env = @eval.Env::new()
  let code = @eval.load(env, "1 + 2 9")
  let (value, rest) = @eval.do_next(env, code)
  assert_true(value is @value.Integer(3L))
  assert_true(code.same(rest))
  assert_eq(rest.index(), Some(3))
  let (last, tail) = @eval.do_next(env, rest)
  assert_true(last is @value.Integer(9L))
  assert_eq(tail.index(), Some(4))
  let (empty, still) = @eval.do_next(env, tail)
  assert_true(empty is @value.Unset)
  assert_true(tail.same(still))
  let (one, remainder) = @eval.do_next(env, @eval.load(env, "1 2"))
  assert_true(one is @value.Integer(1L))
  match remainder.series().unwrap().item(1).unwrap() {
    @value.Integer(n) => assert_eq(n, 2L)
    _ => fail("remainder")
  }
  let (literal, none) = @eval.do_next(env, @value.Integer(2L))
  assert_true(literal is @value.Integer(2L))
  assert_true(none is @value.None)
  let made = @eval.run(env, "a: []")
  let (unset, bound) = @eval.do_next(env, made)
  assert_true(unset is @value.Unset)
  assert_true(made.same(bound))
  // Empty series stays at 0. Rebol's 1-based index? of that tail is 1.
  assert_eq(bound.index(), Some(0))
}

///|
test "an unknown word and a bare infix op fail" {
  let env = @eval.Env::new()
  let missing = try {
    @eval.run(env, "a") |> ignore
    false
  } catch {
    error => error.id() == "no-value"
  }
  assert_true(missing)
  let bare = try {
    @eval.run(env, "+ 1") |> ignore
    false
  } catch {
    error => error.id() == "no-op-arg"
  }
  assert_true(bare)
}
