///|
test "words-of lists object fields and map keys in order" {
  // c-frame.c Make_Object_Block and t-map.c Map_To_Block.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(words-of make object! [b: 2 a: 1]) = [b a] (words-of make object! []) = [] (words-of make map! [b: 2 a: 1]) = [b a] (words-of make map! [\"x\" 1 a: 2]) = [\"x\" a] ((try [words-of 1])/id) = 'expect-arg]) = reduce [true true true true true]",
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
    @eval.run(env, "o: make object! [a: 4] in o 'a") is @value.Integer(4L),
  )
  assert_true(
    @eval.run(env, "a: 9 o: make object! [a: 1] b: [a] bind b o first reduce b")
    is @value.Integer(1L),
  )
  assert_true(@eval.run(env, "unbind b first reduce b") is @value.Integer(9L))
}
