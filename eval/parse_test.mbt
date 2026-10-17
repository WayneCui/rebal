///|
test "parse literals, alternatives, some, any, end, and a bitset" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(parse {abc} [{ab} {c}]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {abc} [{ab} {d}]) = false") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {abc} [{a}]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {abc} [{a} end]) = false") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(parse {} [end]) = true") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(parse {b} [{a} | {b}]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {aaab} [some {a} {b}]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {aa} [some {a} {a}]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {b} [any {a} {b}]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {b} [some {a}]) = false") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse [1 2 3] [1 2]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {b} reduce [make bitset! {abc}]) = true")
    is @value.Logic(true),
  )
}
