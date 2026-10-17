///|
test "clean-path resolves dots and bases a relative file on what-dir" {
  let env = @eval.Env::new()
  @eval.make_dir("/tmp/rebal-cwd")
  assert_eq(@mold.mold_text(@eval.run(env, "clean-path %/a/b/../c")), "%/a/c")
  assert_true(
    @eval.run(env, "(clean-path %/a/./b/) = %/a/b/") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(clean-path %/a//b) = %/a/b") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(clean-path %/../../b) = %/b") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(clean-path \"a/../../b\") = \"../b\"")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(clean-path http://example.com/a/../b) = http://example.com/b",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "old: what-dir here: change-dir %/tmp/rebal-cwd made: clean-path %foo back: change-dir old all [made = append copy here \"foo\" back = old]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(clean-path/only %a/../b) = %b") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(clean-path/dir %/a/b) = %/a/b/") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(clean-path/only/dir %a/../c) = %c/") is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "clean-path/foo %/a") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
