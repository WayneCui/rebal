///|
test "union, intersect, difference, exclude, and unique" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(mold union [1 2] [2 3]) = {[1 2 3]}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold intersect [1 2 3] [2 3 4]) = {[2 3]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold difference [1 2 3] [2 3 4]) = {[1 4]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold exclude [1 2 3] [2 3 4]) = {[1]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold unique [1 2 1 3]) = {[1 2 3]}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold union {ab} {bc}) = {\"abc\"}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "s: [1 2] union s [2 3] (mold s) = {[1 2]}")
    is @value.Logic(true),
  )
}
