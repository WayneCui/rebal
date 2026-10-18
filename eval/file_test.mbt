///|
test "load, save, and do of a script file" {
  let env = @eval.Env::new()
  @eval.write_file("/tmp/rebal-script.r3", "Rebol [title: {t}]\n1 + 2\n")
  assert_true(@eval.run(env, "do %/tmp/rebal-script.r3") is @value.Integer(3L))
  assert_true(
    @eval.run(env, "(load %/tmp/rebal-script.r3) = [1 + 2]")
    is @value.Logic(true),
  )
  @eval.write_file("/tmp/rebal-one.r3", "Rebol [title: {t}]\n3\n")
  assert_true(
    @eval.run(env, "(load %/tmp/rebal-one.r3) = 3") is @value.Logic(true),
  )
  @eval.write_file("/tmp/rebal-header.r3", "REBOL [a: 1]\n1 2\n")
  assert_true(
    @eval.run(env, "(load %/tmp/rebal-header.r3) = [1 2]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(load {Rebol [title: {t}] 1 2}) = [1 2]")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(load {4}) = 4") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(load {Rebol 1}) = [Rebol 1]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "do {Rebol [title: {t}] 2 + 3}") is @value.Integer(5L),
  )
  assert_true(
    @eval.run(
      env, "save %/tmp/rebal-save.r3 [1 + 2] (load %/tmp/rebal-save.r3) = [1 + 2]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "save %/tmp/rebal-num.r3 1 + 2 do %/tmp/rebal-num.r3")
    is @value.Integer(3L),
  )
  assert_true(
    @eval.run(env, "(type? save %/tmp/rebal-save.r3 3) = file!")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(load %/tmp/rebal-save.r3) = 3") is @value.Logic(true),
  )
  let missing = try {
    @eval.run(env, "load %/tmp/rebal-no-such-file.r3") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(missing)
  let bad = try {
    @eval.run(env, "save 1 2") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}

///|
test "save into a binary round-trips through load" {
  // codecs-test.r3 "SAVE to binary!". none returns the script bytes.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(load save #{} \"1\") = \"1\" (load save #{} #{CAFE}) = #{CAFE} (load save #{} [1 2]) = [1 2] (save none \"1\") = #{2231220A} (save #{} #{CAFE}) = #{237B434146457D0A}]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}
