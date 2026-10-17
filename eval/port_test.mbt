///|
test "ports dispatch by scheme before any scheme is installed" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(type? make port! [scheme: 'file ref: %a]) = port!")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "p: make port! [scheme: 'file ref: %a] (mold p) = {port!}")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "p/scheme/name = 'file") is @value.Logic(true))
  assert_true(@eval.run(env, "p/spec/scheme = 'file") is @value.Logic(true))
  assert_true(@eval.run(env, "p/spec/ref = %a") is @value.Logic(true))
  assert_true(@eval.run(env, "p = p") is @value.Logic(true))
  assert_true(
    @eval.run(env, "q: make port! [scheme: 'file] (p = q) = false")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "d: make port! %a/ d/scheme/name = 'dir")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "u: make port! http://example.com/a u/scheme/name = 'http")
    is @value.Logic(true),
  )
  let missing = try {
    @eval.run(env, "open make port! [scheme: 'zzz]") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "port"
        _ => false
      }
  }
  assert_true(missing)
  let bad = try {
    @eval.run(env, "open 1") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "open"
        _ => false
      }
  }
  assert_true(bad)
  let closed = try {
    @eval.run(env, "close 1") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "close"
        _ => false
      }
  }
  assert_true(closed)
  let read = try {
    @eval.run(env, "read p") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "port"
        _ => false
      }
  }
  assert_true(read)
  let wrote = try {
    @eval.run(env, "write 1 2") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "write"
        _ => false
      }
  }
  assert_true(wrote)
  let asked = try {
    @eval.run(env, "query http://example.com") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "port"
        _ => false
      }
  }
  assert_true(asked)
}
