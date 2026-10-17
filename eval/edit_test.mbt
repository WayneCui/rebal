///|
test "clear, take, reverse, swap, change, and trim" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "s: [1 2 3] clear next s (mold head s) = {[1]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "s: [1 2 3] take s (mold s) = {[2 3]}") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "s: {ab} (take s) = #\"a\"") is @value.Logic(true))
  assert_true(
    @eval.run(env, "s: [1 2 3] reverse s (mold s) = {[3 2 1]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "a: [1 2] b: [3 4] swap a b (mold a) = {[3 2]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "a: [1 2] b: [3 4] swap a b (mold b) = {[1 4]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "s: [a b c] change s [1 2] (mold head s) = {[1 2 c]}")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(trim {  ab  }) = {ab}") is @value.Logic(true))
}
