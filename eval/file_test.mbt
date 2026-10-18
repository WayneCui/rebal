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

///|
test "save/compress writes zlib, a header, or a base-64 script" {
  // codecs-test.r3 "SAVE/compress". false is the payload alone.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(save/compress none [print \"Hello World!\"] false) = #{789C2B28CACC2B5150F248CDC9C95708CF2FCA495154E20200526B06D9} (load decompress save/compress none [print \"Hello World!\"] false 'zlib) = [print \"Hello World!\"] (save/compress none [print \"Hello World!\"] true) = #{5245424F4C205B0A202020206F7074696F6E733A205B636F6D70726573735D0A5D0A789C2B28CACC2B5150F248CDC9C95708CF2FCA495154E20200526B06D9} (save/compress none [print \"Hello World!\"] 'script) = #{5245424F4C205B0A202020206F7074696F6E733A205B636F6D70726573735D0A5D0A3634237B654A77724B4D724D4B314651386B6A4E79636C58434D3876796B6C52564F494341464A7242746B3D7D}]) = reduce [true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "load reads a compressed script and can keep its header" {
  // codecs-test.r3 "SAVE/compress". /header puts the object first.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "b: save/compress none [print \"Hello World!\"] true s: save/compress none [print \"Hello World!\"] 'script (reduce [(load b) = [print \"Hello World!\"] (load s) = [print \"Hello World!\"] (length? load/header b) = 3 (type? pick load/header b 1) = object! ((pick load/header b 1)/options) = [compress] ((pick load/header b 1)/title) = \"Untitled\" ((pick load/header b 1)/version) = 0.0.0 ((pick load/header s 1)/options) = [compress] (load/header {1}) = reduce [none 1] ((pick load/header {Rebol [title: \"t\"] 2} 1)/title) = \"t\" (pick load/header {Rebol [title: \"t\"] 2} 2) = 2]) = reduce [true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
