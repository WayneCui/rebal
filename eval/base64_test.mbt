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
    @eval.run(env, "enbase {f} 36") |> ignore
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

///|
test "enbase/part and debase/part limit the input" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(enbase/part {foobar} 64 3) = enbase {foo} 64")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/part tail {foobar} 16 -3) = enbase {bar} 16")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase/part {Zm9vYmFy} 64 4) = #{666F6F}")
    is @value.Logic(true),
  )
  let other = try {
    @eval.run(env, "enbase/only {f} 64") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(other)
}

///|
test "enbase/url uses the url alphabet and omits padding" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(enbase/url {f} 64) = {Zg}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/url {fo} 64) = {Zm8}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/url {foo} 64) = {Zm9v}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/url #{FBFFEF} 64) = {-__v}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase/url {-__v} 64) = #{FBFFEF}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/flat {foo} 64) = {Zm9v}") is @value.Logic(true),
  )
}

///|
test "enbase and debase round-trip ascii85" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(enbase {} 85) = {}") is @value.Logic(true))
  assert_true(@eval.run(env, "(enbase {h} 85) = {BE}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase {hell} 85) = {BOu!r}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase {hello world!} 85) = {BOu!rD]j7BEbo80}")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(enbase #{00} 85) = {!!}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase #{00000000} 85) = {z}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase #{0000000000000000} 85) = {zz}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase #{ffffffff} 85) = {s8W-!}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase #{0100000000} 85) = {!<<*\"!!}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(debase {BOu!rD]j7BEbo80} 85) = #{68656C6C6F20776F726C6421}",
    )
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(debase {B E} 85) = #{68}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(debase \"B^-E\" 85) = #{68}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase \"B^/E\" 85) = #{68}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/part {hello world!} 85 5) = {BOu!rDZ}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase/part {BOu!rDZ!!!!!} 85 7) = #{68656C6C6F}")
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "debase {abcx} 85") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
  let mark = try {
    @eval.run(env, "debase {~>} 85") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(mark)
  let wide = try {
    @eval.run(env, "debase {s8W-\"} 85") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(wide)
}
