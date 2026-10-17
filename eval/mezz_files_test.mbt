///|
test "dirize adds a slash and undirize removes one, without changing the source" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(last \"ab\") = #\"b\"") is @value.Logic(true))
  assert_true(@eval.run(env, "(last [1 2 3]) = 3") is @value.Logic(true))
  assert_true(@eval.run(env, "(last \"\") = none") is @value.Logic(true))
  @eval.run(env, "p: %foo") |> ignore
  assert_true(@eval.run(env, "(dirize p) = %foo/") is @value.Logic(true))
  assert_true(@eval.run(env, "p = %foo") is @value.Logic(true))
  assert_true(@eval.run(env, "(dirize %foo/) = %foo/") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(dirize \"foo\") = \"foo/\"") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(undirize %foo/) = %foo") is @value.Logic(true))
  assert_true(@eval.run(env, "(undirize %foo) = %foo") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(undirize http://example.com/a/) = http://example.com/a")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(type? copy %foo) = file!") is @value.Logic(true))
}

///|
test "exists? returns the file type and size? returns the length" {
  let env = @eval.Env::new()
  @eval.run(env, "write %/tmp/rebal-exists.txt {ab}") |> ignore
  assert_true(
    @eval.run(env, "(exists? %/tmp/rebal-exists.txt) = 'file")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(size? %/tmp/rebal-exists.txt) = 2") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(exists? %/tmp/) = 'dir") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(exists? %/tmp/rebal-no-such-exists.txt) = none")
    is @value.Logic(true),
  )
}
