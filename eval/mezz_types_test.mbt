///|
test "to string! joins values and decodes UTF-8 binaries" {
  // t-string.c make_string. A block is tight. A BOM is dropped. CR stays.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(to string! []) = \"\" (to string! [1 2]) = \"12\" (to string! [1 [2] \"a\"]) = \"12a\" (to string! [1 \" a\"]) = \"1 a\" (to string! 'word) = \"word\" (to string! first [a:]) = \"a\" (to string! #\"A\") = \"A\" (to string! next \"ab\") = \"b\" (to string! %a/b) = \"a/b\" (to string! <a>) = \"a\" (to string! first [a/b]) = \"a/b\" (to string! #{6162}) = \"ab\" (to string! #{EFBBBF6162}) = \"ab\" (to string! #{FFFE61006200}) = \"ab\" (to string! #{610D0A62}) = \"a^M^/b\" (to-string []) = \"\" (load to-string []) = [] ((try [to string! none])/id) = 'bad-make-arg ((try [to string! #{FF}])/id) = 'invalid-utf]) = reduce [true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "to-integer and the other to-* words call to" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(to-integer 1:0:0) = 3600") is @value.Logic(true))
  assert_true(@eval.run(env, "(to-integer #\"a\") = 97") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(to-integer #\"^(4E00)\") = 19968") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(to-decimal 1%) = 0.01") is @value.Logic(true))
  assert_true(@eval.run(env, "(to-percent 1) = 100%") is @value.Logic(true))
  assert_true(@eval.run(env, "(to-pair 3) = 3x3") is @value.Logic(true))
}

///|
test "to-word and to-file convert strings and words" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(to word! \"abc\") = 'abc (to-word \"x-y\") = 'x-y (to word! 'a) = 'a (type? to word! \"q\") = word! (to file! \"a/b\") = %a/b (type? to-file \"q\") = file! (to file! %a) = %a]) = reduce [true true true true true true true]",
    )
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "to word! 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}

///|
test "to-logic keeps only none and false false" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(to logic! 0) = true (to logic! \"\") = true (to logic! none) = false (to logic! false) = false (to-logic 1) = true]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "type predicates match the datatype words" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [error? try [nope] not error? 1 object? make object! [] map? make map! [] string? \"a\" block? [] paren? first [(1)] word? 'a file? %a]) = reduce [true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(reduce [logic? true integer? 1 not integer? 1.5 function? :print function? func [] [] not function? 1 closure? closure [] [] op? :+ port? open console://]) = reduce [true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(reduce [error? try [nope] not error? try [1]]) = reduce [true true]",
    )
    is @value.Logic(true),
  )
}
