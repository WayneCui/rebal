///|
test "money scans, molds, converts, and combines" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(mold $1) = {$1}") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold $1.5) = {$1.5}") is @value.Logic(true))
  assert_true(@eval.run(env, "(mold -$2) = {-$2}") is @value.Logic(true))
  assert_true(@eval.run(env, "$1 = make money! 1") is @value.Logic(true))
  assert_true(@eval.run(env, "$1 = make money! 100%") is @value.Logic(true))
  assert_true(@eval.run(env, "$1 + $2 = $3") is @value.Logic(true))
  assert_true(@eval.run(env, "$1 + 0.5 = $1.5") is @value.Logic(true))
  assert_true(@eval.run(env, "$1 = 1") is @value.Logic(true))
}
