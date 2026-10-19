///|
test "collect gathers kept values and keep splices blocks" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(collect [keep 1 keep 2]) = [1 2]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(collect [keep [1 2] keep 3]) = [1 2 3]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(collect [keep/only [1 2]]) = [[1 2]]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(collect/only [keep [1 2] keep 3]) = [[1 2] 3]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(collect [foreach x [1 2 3] [keep x * 2]]) = [2 4 6]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(collect [keep collect [keep 1] keep 2]) = [1 2]")
    is @value.Logic(true),
  )
  let bare = try {
    @eval.run(env, "keep 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bare)
}
