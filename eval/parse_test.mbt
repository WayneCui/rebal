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

///|
test "parse to and thru a target, including an absolute index" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(parse {ba} [to #\"a\" skip end]) = true")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {ba} [to #\"a\" {ba}]) = false")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {abcd} [to 2 {bcd}]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {abcd} [thru 2 {cd}]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {abcd} [thru 4 end]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {abcd} [{ab} to 1 {abcd}]) = true")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {xxab} [thru {ab} end]) = true")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {xxab} [to [{zz} | {ab}] {ab}]) = true")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse [1 2 a] [thru word! end]) = true")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "a: make bitset! {a} (parse {ba} [to a skip end]) = true")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {abc} [to {z}]) = false") is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "parse {foo} [thru some {0}]") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}

///|
test "parse copy, set, and a saved input position" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "parse {xyz} [copy f to end] f = {xyz}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "parse {abc} [#\"a\" copy x to end] x = {bc}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "parse {ab} [set c skip] c = #\"a\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "parse {ab} [set c {ab}] c = #\"a\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "parse [1 2] [set n 1] n = 1") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "parse {} [set c end] c = none") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "parse {} [copy c end] c = {}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "parse {abc} [skip b:] b = {bc}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "parse {abc} [a: {a} :a {abc}]") is @value.Logic(true),
  )
}

///|
test "parse into a nested series, and break out of some" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(parse [[1 2] 3] [into [1 2] 3]) = true")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse [[1 2]] [into [1]]) = false") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse [{ab}] [into [{ab}]]) = true") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(parse {aaa} [some [break] {aaa}]) = true")
    is @value.Logic(true),
  )
  let bare = try {
    @eval.run(env, "parse {a} [break]") |> ignore
    false
  } catch {
    error => error.id() == "parse"
  }
  assert_true(bare)
}
