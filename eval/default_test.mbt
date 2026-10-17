///|
test "a lit-word argument is not evaluated, and default fills an empty word" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "f: func ['x] [x] (type? f y) = word!") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "g: func ['x y] [y] (g 1 2 + 3) = 5") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "h: func [x 'y] [x] (h 1 + 2 9) = 3") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(default width 4) = 4") is @value.Logic(true))
  assert_true(@eval.run(env, "width = 4") is @value.Logic(true))
  assert_true(@eval.run(env, "(default width 9) = 9") is @value.Logic(true))
  assert_true(@eval.run(env, "width = 4") is @value.Logic(true))
  assert_true(
    @eval.run(env, "width: none (default width 2) = 2") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "width = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "(none? none) = true") is @value.Logic(true))
  assert_true(@eval.run(env, "(none? 0) = false") is @value.Logic(true))
  let bad = try {
    @eval.run(env, "f: func ['x [word!]] [x] f 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
