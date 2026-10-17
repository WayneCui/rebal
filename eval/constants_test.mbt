///|
test "boot installs the base constants and their aliases" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(on = true) and (off = false)") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(yes = true) and (no = false) and (zero = 0)")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(null = #\"^@\") and (escape = #\"^[\")")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(sp = space) and (bs = backspace) and (lf = newline)")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "crlf = \"^M^J\"") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(slash = #\"/\") and (backslash = #\"\\\")")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "dbl-quote = #\"^\"\"") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(find whitespace space) = space") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(find whitespace #\"a\") = none") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(min 8 2) = 2") is @value.Logic(true))
  assert_true(@eval.run(env, "(max 8 2) = 8") is @value.Logic(true))
  assert_true(@eval.run(env, "(abs -3) = 3") is @value.Logic(true))
  assert_true(@eval.run(env, "(empty? \"\") = true") is @value.Logic(true))
  assert_true(@eval.run(env, "(! false) = true") is @value.Logic(true))
  let stopped = try {
    @eval.run(env, "q") |> ignore
    false
  } catch {
    error => error.id() == "quit"
  }
  assert_true(stopped)
  let escaped = try {
    @eval.run(env, "try [q]") |> ignore
    false
  } catch {
    error => error.id() == "quit"
  }
  assert_true(escaped)
}
