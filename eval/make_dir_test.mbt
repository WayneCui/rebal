///|
test "make-dir creates a directory and keeps an existing one" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(make-dir %/tmp/rebal-make-dir-a) = %/tmp/rebal-make-dir-a/",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(exists? %/tmp/rebal-make-dir-a/) = 'dir")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(make-dir %/tmp/rebal-make-dir-a/) = %/tmp/rebal-make-dir-a/",
    )
    is @value.Logic(true),
  )
  @eval.run(env, "write %/tmp/rebal-make-dir-file {x}") |> ignore
  let blocked = try {
    @eval.run(env, "make-dir %/tmp/rebal-make-dir-file") |> ignore
    false
  } catch {
    error => error.id() == "cannot" || error.id() == "cannot-open"
  }
  assert_true(blocked)
  assert_true(
    @eval.run(
      env, "(make-dir/deep %/tmp/rebal-deep-root/a/b) = %/tmp/rebal-deep-root/a/b/",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(exists? %/tmp/rebal-deep-root/) = 'dir")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(exists? %/tmp/rebal-deep-root/a/b/) = 'dir")
    is @value.Logic(true),
  )
  let shallow = try {
    @eval.run(env, "make-dir %/tmp/rebal-deep-shallow/child") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(shallow)
  assert_true(
    @eval.run(env, "(exists? %/tmp/rebal-deep-shallow) = none")
    is @value.Logic(true),
  )
}
