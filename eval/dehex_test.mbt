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

///|
test "dehex/uri and dehex/escape decode a chosen mark" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(dehex/uri {a+b%2B}) = {a b+}") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(dehex {a+b%2B}) = {a+b+}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(dehex/escape {C#23#20#XX} #\"#\") = {C# #XX}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(dehex/escape {#28š#29} #\"#\") = {(š)}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(dehex/escape {a_b=5F} #\"=\") = {a_b_}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(dehex/uri/escape {a_b=5F} #\"=\") = {a b_}")
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "dehex/only {a}") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
  let mark = try {
    @eval.run(env, "dehex/escape {a} 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(mark)
}
