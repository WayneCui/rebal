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
    @eval.run(env, "enbase {f} 85") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(other)
}

///|
test "enbase and debase round-trip base 16" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(enbase {f} 16) = {66}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase {foobar} 16) = {666F6F626172}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase #{00FF} 16) = {00FF}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase {666F6F626172} 16) = #{666F6F626172}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase {66 6f} 16) = #{666F}") is @value.Logic(true),
  )
  let odd = try {
    @eval.run(env, "debase {666} 16") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(odd)
}

///|
test "enbase and debase round-trip base 2" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(enbase {f} 2) = {01100110}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase #{0001} 2) = {0000000000000001}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase {01100110} 2) = #{66}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase {0110 0110} 2) = #{66}") is @value.Logic(true),
  )
  let short = try {
    @eval.run(env, "debase {0110011} 2") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(short)
}
