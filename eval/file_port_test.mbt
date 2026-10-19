///|
test "file ports read, write, and query text" {
  let env = @eval.Env::new()
  @eval.write_file("/tmp/rebal-file-port.txt", "ab")
  assert_true(
    @eval.run(env, "(read %/tmp/rebal-file-port.txt) = {ab}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(read/string %/tmp/rebal-file-port.txt) = {ab}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "write %/tmp/rebal-file-port.txt {cd} (read %/tmp/rebal-file-port.txt) = {cd}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(type? open %/tmp/rebal-file-port.txt) = port!")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "p: open %/tmp/rebal-file-port.txt (read p) = {cd} close p (type? p) = port!",
    )
    is @value.Logic(true),
  )
  let shut = try {
    @eval.run(env, "read p") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(shut)
  let made = try {
    @eval.run(env, "read make port! %/tmp/rebal-file-port.txt") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(made)
  assert_true(
    @eval.run(env, "q: query %/tmp/rebal-file-port.txt q/size = 2")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "q/type = 'file") is @value.Logic(true))
  assert_true(
    @eval.run(env, "q/name = %/tmp/rebal-file-port.txt") is @value.Logic(true),
  )
  let missing = try {
    @eval.run(env, "read %/tmp/rebal-no-such-port.txt") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(missing)
}
