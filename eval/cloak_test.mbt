///|
test "encloak scrambles a binary and decloak restores it" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(encloak #{616263} {key}) = #{0BA811}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decloak encloak #{616263} {key} {key}) = #{616263}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "b: #{616263} encloak b {key} b = #{0BA811}")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(encloak #{} {key}) = #{}") is @value.Logic(true))
  let bad = try {
    @eval.run(env, "encloak {abc} {key}") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
