///|
test "functions bind parameters and keep outer words" {
  // evaluation-test.r3:127 do-func-1, :132 do-func-2, :136 do-func-3, :139 do-func-4
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "f: func [] [1] f") is @value.Integer(1L))
  assert_true(@eval.run(env, "f: func [i] [2 * i] f 2") is @value.Integer(4L))
  assert_true(@eval.run(env, "f: does [3] f") is @value.Integer(3L))
  assert_true(
    @eval.run(env, "n: 4 f: [func [i] [n * i] 4] do reduce f")
    is @value.Integer(16L),
  )
  assert_true(@eval.run(env, "n: 4 f: func [n] [n] f 7") is @value.Integer(7L))
  match @eval.run(env, "a: does [\"OK\"] do 'a") {
    @value.Seq(text, _) => {
      assert_true(text.datatype() == @value.String)
      assert_eq(text.code(0), Some('O'.to_int()))
      assert_eq(text.code(1), Some('K'.to_int()))
    }
    _ => fail("do word")
  }
  assert_true(@eval.run(env, "b: 23 do 'b") is @value.Integer(23L))
  match @eval.run(env, "b: [1 + 2] do 'b") {
    @value.Seq(block, _) => {
      assert_true(block.datatype() == @value.Block)
      assert_eq(block.length(), 3)
    }
    _ => fail("do block word")
  }
}

///|
test "objects and paths" {
  // evaluation-test.r3:168, series-test.r3:2882
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "o: make object! [oo: make object! [ooo: make object! [a: 1]]] o/oo/ooo/a",
    )
    is @value.Integer(1L),
  )
  assert_true(@eval.run(env, "b: [b 1] b/b") is @value.Integer(1L))
  assert_true(
    @eval.run(env, "o: make object! [a: 1] o/a: 2 o/a") is @value.Integer(2L),
  )
  assert_true(@eval.run(env, "b: [b 1] b/b: 9 b/b") is @value.Integer(9L))
  assert_true(
    @eval.run(env, "o: make object! [a: 1 f: does [a]] o/f")
    is @value.Integer(1L),
  )
  match @eval.run(env, "b: [b 1] b/1") {
    @value.Sym(_, lexeme) => assert_eq(lexeme.spelling(), "b")
    _ => fail("pick path")
  }
  let missing = try {
    @eval.run(env, "o: make object! [a: 1] o/z") |> ignore
    false
  } catch {
    error => error.id() == "invalid-path"
  }
  assert_true(missing)
}

///|
test "reduce evaluates expressions and drops unset" {
  // evaluation-test.r3:253
  let env = @eval.Env::new()
  let cell = @eval.run(env, "a: 123 reduce [a 3 + 5 'z]")
  match cell {
    @value.Seq(block, _) => {
      assert_true(block.item(0).unwrap() is @value.Integer(123L))
      assert_true(block.item(1).unwrap() is @value.Integer(8L))
      match block.item(2).unwrap() {
        @value.Sym(datatype, lexeme) => {
          assert_true(datatype == @value.Word)
          assert_eq(lexeme.spelling(), "z")
        }
        _ => fail("word")
      }
    }
    _ => fail("reduce")
  }
  assert_true(@eval.run(env, "reduce none") is @value.None)
  match @eval.run(@eval.Env::new(), "try [missing]") {
    @value.Error(error) => {
      assert_eq(error.id, "no-value")
      assert_eq(error.arg1, "missing")
    }
    _ => fail("try")
  }
  assert_true(@eval.run(env, "length? form \"ab\"") is @value.Integer(2L))
  assert_true(@eval.run(env, "length? mold \"ab\"") is @value.Integer(4L))
}
