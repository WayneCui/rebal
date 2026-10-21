///|
test "enbase and debase round-trip base 64" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(enbase/base {f} 64) = {Zg==}") is @value.Logic(true))
  assert_true(@eval.run(env, "(enbase/base {fo} 64) = {Zm8=}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase/base {foo} 64) = {Zm9v}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base {foobar} 64) = {Zm9vYmFy}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{00FF} 64) = {AP8=}") is @value.Logic(true),
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
    @eval.run(env, "(debase enbase/base {hi} 64 64) = #{6869}") is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "debase {!!!!} 64") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
  let other = try {
    @eval.run(env, "enbase/base {f} 58") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(other)
}

///|
test "enbase and debase round-trip base 16" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(enbase/base {f} 16) = {66}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase/base {foobar} 16) = {666F6F626172}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{00FF} 16) = {00FF}") is @value.Logic(true),
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
    @eval.run(env, "(enbase/base {f} 2) = {01100110}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{0001} 2) = {0000000000000001}")
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
    @eval.run(env, "(enbase/base/part {foobar} 64 3) = enbase/base {foo} 64")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base/part tail {foobar} 16 -3) = enbase/base {bar} 16")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase/part {Zm9vYmFy} 64 4) = #{666F6F}")
    is @value.Logic(true),
  )
  let other = try {
    @eval.run(env, "enbase/only {f}") |> ignore
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
    @eval.run(env, "(enbase/url {f}) = {Zg}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/url {fo}) = {Zm8}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/url {foo}) = {Zm9v}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/url #{FBFFEF}) = {-__v}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase/url {-__v} 64) = #{FBFFEF}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/flat {foo}) = {Zm9v}") is @value.Logic(true),
  )
}

///|
test "enbase and debase round-trip ascii85" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(enbase/base {} 85) = {}") is @value.Logic(true))
  assert_true(@eval.run(env, "(enbase/base {h} 85) = {BE}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase/base {hell} 85) = {BOu!r}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base {hello world!} 85) = {BOu!rD]j7BEbo80}")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(enbase/base #{00} 85) = {!!}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase/base #{00000000} 85) = {z}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{0000000000000000} 85) = {zz}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{ffffffff} 85) = {s8W-!}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{0100000000} 85) = {!<<*\"!!}")
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
    @eval.run(env, "(enbase/base/part {hello world!} 85 5) = {BOu!rDZ}")
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

///|
test "enbase and debase round-trip base 36" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(enbase/base debase {} 36 36) = {}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base debase {000} 36 36) = {0}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base debase {001} 36 36) = {1}") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(enbase/base #{00} 36) = {0}") is @value.Logic(true))
  assert_true(@eval.run(env, "(enbase/base #{24} 36) = {10}") is @value.Logic(true))
  assert_true(@eval.run(env, "(enbase/base #{40} 36) = {1S}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enbase/base #{0400} 36) = {SG}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{01301D87} 36) = {BV6H3}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{6DDAFBAD} 36) = {UHBC8D}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{36D7259C2F370F4A} 36) = {U0TPLAQIV70Q}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enbase/base #{FFFFFFFFFFFFFFFF} 36) = {3W5E11264SGSF}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(debase {bv6h3} 36) = #{0000000001301D87}")
    is @value.Logic(true),
  )
  let long = try {
    @eval.run(env, "debase {00000000000000} 36") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(long)
  let mark = try {
    @eval.run(env, "debase {0.0} 36") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(mark)
  let wide = try {
    @eval.run(env, "enbase/base #{000000000000000000} 36") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(wide)
}
