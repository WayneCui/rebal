///|
test "repend reduces then appends, reform forms, join copies a series" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "series? [1]") is @value.Logic(true))
  assert_true(@eval.run(env, "series? \"ab\"") is @value.Logic(true))
  assert_true(@eval.run(env, "series? 1") is @value.Logic(false))
  @eval.run(env, "b: [1]") |> ignore
  assert_true(
    @eval.run(env, "(repend b [2 + 3 4]) = [1 5 4]") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "b = [1 5 4]") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(reform [1 + 2 4]) = {3 4}") is @value.Logic(true),
  )
  @eval.run(env, "a: [1]") |> ignore
  assert_true(@eval.run(env, "(join a [2 + 3]) = [1 5]") is @value.Logic(true))
  assert_true(@eval.run(env, "a = [1]") is @value.Logic(true))
  assert_true(@eval.run(env, "(reduce {ab}) = {ab}") is @value.Logic(true))
  assert_true(@eval.run(env, "(join 12 {ab}) = {12ab}") is @value.Logic(true))
}
