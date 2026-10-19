///|
test "offset, last, charset, and remold follow the series helpers" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(empty? none) = true") is @value.Logic(true))
  assert_true(@eval.run(env, "(empty? []) = true") is @value.Logic(true))
  assert_true(@eval.run(env, "(empty? [1]) = false") is @value.Logic(true))
  @eval.run(env, "s: [a b c d]") |> ignore
  assert_true(@eval.run(env, "(offset? s next s) = 1") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(offset? next s skip s 3) = 2") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(offset? skip s 3 s) = -3") is @value.Logic(true))
  assert_true(@eval.run(env, "(last? [1]) = true") is @value.Logic(true))
  assert_true(@eval.run(env, "(single? [1]) = true") is @value.Logic(true))
  assert_true(@eval.run(env, "(last? [1 2]) = false") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(find charset {abc} #\"b\") = #\"b\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(remold [1 + 2 4]) = {[3 4]}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(rejoin [\"a\" 1 + 2 \"x\"]) = \"a3x\"")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(rejoin []) = []") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(rejoin [none]) = \"none\"") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(rejoin [a: 1]) = \"1\"") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(rejoin [\"STATUS: \" 3]) = \"STATUS: 3\"")
    is @value.Logic(true),
  )
}
