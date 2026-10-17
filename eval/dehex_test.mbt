///|
test "dehex turns percent escapes into bytes" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(dehex {a%20b}) = {a b}") is @value.Logic(true))
  assert_true(@eval.run(env, "(dehex {100%25}) = {100%}") is @value.Logic(true))
  assert_true(@eval.run(env, "(dehex {a%2}) = {a%2}") is @value.Logic(true))
  assert_true(@eval.run(env, "(dehex {a%zz}) = {a%zz}") is @value.Logic(true))
  assert_true(@eval.run(env, "(dehex {%%20}) = {% }") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(dehex #{6125323062}) = #{612062}") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(dehex %\"a%2Fb\") = %a/b") is @value.Logic(true))
  assert_true(@eval.run(env, "(dehex {}) = {}") is @value.Logic(true))
  let bad = try {
    @eval.run(env, "dehex 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
