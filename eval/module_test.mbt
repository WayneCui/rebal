///|
test "module keeps private words and import copies exports" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(type? sys) = object!") is @value.Logic(true))
  assert_true(
    @eval.run(
      env, "m: module [title: {t} exports: [n]] [hidden: 2 n: hidden + 1] import m all [n = 3 not value? 'hidden]",
    )
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(type? m) = module!") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold m) = {module!}") is @value.Logic(true))
  let bad = try {
    @eval.run(env, "import 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
