///|
test "suffix? keeps the tail after the last dot" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(suffix? %file.txt) = %.txt") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(suffix? %dir.name/file.txt) = %.txt") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(suffix? %dir.name/file) = none") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(suffix? %file) = none") is @value.Logic(true))
  assert_true(@eval.run(env, "(suffix? \"a.b\") = %.b") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(suffix? http://example.com/a.txt?x=1) = %.txt")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(suffix? http://ex.ample.com/file) = none")
    is @value.Logic(true),
  )
}
