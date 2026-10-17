///|
test "change case, line endings, tabs, and hex escapes in a string" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(mold lowercase {Ab}) = {\"ab\"}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(lowercase #\"A\") = #\"a\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold uppercase {Ab}) = {\"AB\"}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(deline \"a^M^/b^Mc\") = \"a^/b^/c\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enline \"a^/b\") = \"a^M^/b\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(detab \"a^-b\") = \"a   b\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(detab \"^-b\") = \"    b\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(entab \"a    b\") = \"a^-b\"") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(dehex {a%20b}) = {a b}") is @value.Logic(true))
  assert_true(@eval.run(env, "(enhex {a b}) = {a%20b}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "s: {Ab} lowercase s (mold s) = {\"ab\"}")
    is @value.Logic(true),
  )
}
