///|
test "time scans, molds, converts, and combines" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(mold 1:30) = {1:30}") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold 0:0:1) = {0:00:01}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(mold 0:0:0.1) = {0:00:00.1}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold 1:30.5) = {0:01:30.5}") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(make time! 90) = 0:01:30") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(make time! [-1 2 3]) = -1:02:03") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(to integer! 1:0:0) = 3600") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(to decimal! 0:0:1) = 1") is @value.Logic(true))
  assert_true(@eval.run(env, "1:0:0 - 24:00 = -23:00") is @value.Logic(true))
  assert_true(@eval.run(env, "100 + 5:00 = 5:01:40") is @value.Logic(true))
  assert_true(@eval.run(env, "100 - 5:00 = -4:58:20") is @value.Logic(true))
  assert_true(@eval.run(env, "50% * 10:0:0 = 5:00") is @value.Logic(true))
  assert_true(@eval.run(env, "1:30:0 * $5 = $7.5") is @value.Logic(true))
  assert_true(@eval.run(env, "0 < 0:0:0.1") is @value.Logic(true))
  assert_true(@eval.run(env, "0:0:0.1 > 0.0") is @value.Logic(true))
}
