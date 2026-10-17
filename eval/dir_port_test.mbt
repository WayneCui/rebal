///|
test "dir port lists files and marks directories" {
  let env = @eval.Env::new()
  @eval.make_dir("/tmp/rebal-dir-port")
  @eval.write_file("/tmp/rebal-dir-port/a.txt", "a")
  @eval.make_dir("/tmp/rebal-dir-port/sub")
  assert_true(
    @eval.run(env, "(read %/tmp/rebal-dir-port/) = [%a.txt %sub/]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "p: open %/tmp/rebal-dir-port/ p/scheme/name = 'dir")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "q: query %/tmp/rebal-dir-port/ q/type = 'dir")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "q/size = none") is @value.Logic(true))
  assert_true(
    @eval.run(env, "q/name = %/tmp/rebal-dir-port/") is @value.Logic(true),
  )
  let wrote = try {
    @eval.run(env, "write %/tmp/rebal-dir-port/ {no}") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(wrote)
  let missing = try {
    @eval.run(env, "read %/tmp/rebal-no-such-dir/") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(missing)
}
