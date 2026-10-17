///|
test "divide, power, and sign questions" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "10 / 4 = 2.5") is @value.Logic(true))
  assert_true(@eval.run(env, "10 / 5 = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "10 // 3 = 1") is @value.Logic(true))
  assert_true(@eval.run(env, "2 ** 3 = 8") is @value.Logic(true))
  assert_true(@eval.run(env, "1:0:0 / 0:30:0 = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "(negate -3) = 3") is @value.Logic(true))
  assert_true(@eval.run(env, "(absolute -1:30) = 1:30") is @value.Logic(true))
  assert_true(@eval.run(env, "odd? 3") is @value.Logic(true))
  assert_true(@eval.run(env, "even? 4") is @value.Logic(true))
  assert_true(@eval.run(env, "negative? -1") is @value.Logic(true))
  assert_true(@eval.run(env, "positive? 0") is @value.Logic(false))
  assert_true(@eval.run(env, "zero? $0") is @value.Logic(true))
  assert_true(@eval.run(env, "(min 8 2) = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "(max 8 2) = 8") is @value.Logic(true))
  let zero = try {
    @eval.run(@eval.Env::new(), "1 / 0") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(zero)
}
