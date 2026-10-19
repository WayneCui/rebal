///|
test "system options keeps the startup directory" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(type? system) = object!") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(type? system/options) = object!") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(system/options/path) = what-dir") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(type? system/options/args) = block!") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(length? system/options/args) = 0") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "none? system/options/script") is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "kept: system/options/path old: what-dir change-dir %/tmp still: system/options/path = kept back: change-dir old all [still what-dir = old]",
    )
    is @value.Logic(true),
  )
}
