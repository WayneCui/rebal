///|
test "browse hands a url to the opener and returns it" {
  let env = @eval.Env::new()
  @eval.set_browser("/usr/bin/true")
  assert_true(
    @eval.run(env, "(browse http://example.com) = http://example.com")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(browse %/usr/bin/true) = %/usr/bin/true")
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "browse 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
  @eval.set_browser("/usr/bin/false")
  let failed = try {
    @eval.run(env, "browse http://example.com") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(failed)
  @eval.set_browser("/usr/bin/open")
}
