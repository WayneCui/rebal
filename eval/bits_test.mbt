///|
test "round, random, complement, and shift" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(round 1.5) = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "(round -1.5) = -2") is @value.Logic(true))
  assert_true(@eval.run(env, "(round 1.2) = 1") is @value.Logic(true))
  assert_true(@eval.run(env, "(round 0:0:1.6) = 0:00:02") is @value.Logic(true))
  assert_true(@eval.run(env, "(complement 0) = -1") is @value.Logic(true))
  assert_true(@eval.run(env, "(complement 1) = -2") is @value.Logic(true))
  assert_true(@eval.run(env, "(shift 1 1) = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "(shift 2 3) = 16") is @value.Logic(true))
  assert_true(@eval.run(env, "(shift 1 -1) = 0") is @value.Logic(true))
  assert_true(@eval.run(env, "(shift -1 -1) = -1") is @value.Logic(true))
  assert_true(@eval.run(env, "2 << 3 = 16") is @value.Logic(true))
  assert_true(@eval.run(env, "1 << 64 = 1") is @value.Logic(true))
  assert_true(@eval.run(env, "1 << 65 = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "2 >> 1 = 1") is @value.Logic(true))
  assert_true(
    @eval.run(env, "all [(random 5) >= 1 (random 5) <= 5]")
    is @value.Logic(true),
  )
  let overflow = try {
    @eval.run(@eval.Env::new(), "shift 1 63") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(overflow)
}
