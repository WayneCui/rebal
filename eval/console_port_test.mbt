///|
test "console port reads a line and writes formed text" {
  let env = @eval.Env::new()
  @eval.push_console("one\n")
  @eval.push_console("two")
  assert_true(@eval.run(env, "(read console://) = {one}") is @value.Logic(true))
  assert_true(
    @eval.run(
      env, "p: open 'console (read p) = {two} close p (type? p) = port!",
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
  let before = @eval.console_written()
  assert_true(
    @eval.run(env, "write console:// {ab} write console:// 12")
    is @value.Port(_),
  )
  assert_eq(@eval.console_written(), before + "ab12")
  assert_true(
    @eval.run(env, "q: query console:// q/window-cols = 80")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "q/window-rows = 25") is @value.Logic(true))
  assert_true(
    @eval.run(env, "q/length = " + (before.length() + 4).to_string())
    is @value.Logic(true),
  )
}
