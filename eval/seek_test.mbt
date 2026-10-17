///|
test "select the value after a match, and find with refinements" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(select [a 1 b 2] 'b) = 2") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(select {abc} #\"b\") = #\"c\"") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(select [a] 'a) = none") is @value.Logic(true))
  assert_true(@eval.run(env, "(find none 1) = none") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(mold find {abcd} {bc}) = {\"bcd\"}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold find [1 2 3] [2 3]) = {[2 3]}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold find/only [1 [2 3]] [2 3]) = {[[2 3]]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold find/match [x y] 'x) = {[x y]}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold find/match/tail [x y] 'x) = {[y]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold find/last [x x x] 'x) = {[x]}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold find/reverse tail [x] 'x) = {[x]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(find/part [x] 'x 0) = none") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold find/part [x] 'x 1) = {[x]}") is @value.Logic(true),
  )
  let unknown = try {
    @eval.run(env, "find/foo [x] 'x") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(unknown)
}
