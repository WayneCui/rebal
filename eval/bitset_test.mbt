///|
test "make a bitset from a string, a range, or a code" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(type? make bitset! {abc}) = bitset!") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(find make bitset! {abc} #\"b\") = #\"b\"")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(find make bitset! {abc} #\"d\") = none")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(find make bitset! [#\"a\" - #\"c\"] #\"b\") = #\"b\"")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(find make bitset! 98 #\"b\") = #\"b\"")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(find complement make bitset! {a} #\"b\") = #\"b\"")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(find complement make bitset! {a} #\"a\") = none")
    is @value.Logic(true),
  )
}
