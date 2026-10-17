///|
test "closure rebinds a fresh body on each call" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(type? closure [n] [n]) = closure!") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold closure [n] [n]) = {closure!}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "f: func [n] [does [n]] a: f 1 b: f 2 c: closure [n] [does [n]] x: c 1 y: c 2 all [a = 2 x = 1 y = 2]",
    )
    is @value.Logic(true),
  )
}
