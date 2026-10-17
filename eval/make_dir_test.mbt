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
}
