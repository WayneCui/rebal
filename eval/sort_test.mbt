///|
test "sort a block and a string, including reverse order" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "s: [3 1 2] sort s (mold s) = {[1 2 3]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "s: {cba} sort s (mold s) = {\"abc\"}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "s: [1 2 3] sort/reverse s (mold s) = {[3 2 1]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "s: [30 2 10 1 20 3] sort/skip s 2 (mold s) = {[10 1 20 3 30 2]}",
    )
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(sort none) = none") is @value.Logic(true))
  assert_true(
    @eval.run(env, "s: [3 1 2] sort next s (mold head s) = {[3 1 2]}")
    is @value.Logic(true),
  )
  let mixed = try {
    @eval.run(env, "sort [1 {a}]") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(mixed)
}
