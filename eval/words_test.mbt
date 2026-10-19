///|
test "words-of lists object fields and map keys in order" {
  // c-frame.c Make_Object_Block and t-map.c Map_To_Block.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(words-of make object! [b: 2 a: 1]) = [b a] (words-of make object! []) = [] (words-of make map! [b: 2 a: 1]) = [b a] (words-of make map! [\"x\" 1 a: 2]) = [\"x\" a] (words-of func [a /b c] [a]) = [a /b c] (words-of func [a /local b /c d] []) = [a /local b /c d] (words-of func [a [integer!] 'b] []) = [a 'b] (words-of does [1]) = [] (words-of make op! func [a b] [a]) = [a b] ((try [words-of 1])/id) = 'expect-arg]) = reduce [true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "get set and unset address a word" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "a: 1 get 'a") is @value.Integer(1L))
  assert_true(@eval.run(env, "set 'b 2 b") is @value.Integer(2L))
  assert_true(@eval.run(env, "unset 'b") is @value.Unset)
  assert_true(@eval.run(env, "unset? 'b") is @value.Logic(true))
  assert_true(@eval.run(env, "value? 'a") is @value.Logic(true))
  assert_true(@eval.run(env, "unset? 'missing") is @value.Logic(true))
  assert_true(
    @eval.run(
      env, "o: make object! [a: 4 run: does [7]] got: do reduce [get in o 'run] (reduce [(get in o 'a) = 4 (in o 'a) = 'a none? in o 'z none? in o 'self got = 7]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "a: 9 o: make object! [a: 1] b: [a] bind b o first reduce b")
    is @value.Integer(1L),
  )
  assert_true(@eval.run(env, "unbind b first reduce b") is @value.Integer(9L))
}
