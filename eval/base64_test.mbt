///|
test "enbase and debase round-trip base 64" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(enbase {f} 64) = {Zg==}") is @value.Logic(true))
  assert_true(@eval.run(env, "(enbase {fo} 64) = {Zm8=}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase {foo} 64) = {Zm9v}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase {foobar} 64) = {Zm9vYmFy}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase #{00FF} 64) = {AP8=}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase {Zm9vYmFy} 64) = #{666F6F626172}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase {Zm9v YmFy} 64) = #{666F6F626172}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase enbase {hi} 64 64) = #{6869}") is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "debase {!!!!} 64") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
  let other = try {
    @eval.run(env, "enbase {f} 16") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(other)
}
