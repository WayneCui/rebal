///|
test "file, email, url, tag, and issue" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(type? %foo) = file!") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold %foo) = {%foo}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(mold %foo%20bar) = {%foo%20bar}") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "%foo%20bar = %\"foo bar\"") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(type? user@host) = email!") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold user@host) = {user@host}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(type? http://example.com/a) = url!") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold http://example.com/a) = {http://example.com/a}")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(type? <div>) = tag!") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold <div>) = {<div>}") is @value.Logic(true))
  assert_true(@eval.run(env, "(type? #abc) = issue!") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold #abc) = {#abc}") is @value.Logic(true))
  assert_true(@eval.run(env, "(type? #\"a\") = char!") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(type? first [a:]) = set-word!") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold first [a/b]) = {a/b}") is @value.Logic(true),
  )
}
