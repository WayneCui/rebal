///|
test "enhex percent-encodes utf-8 and keeps uri marks in files and urls" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(enhex {šik}) = {%C5%A1ik}") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(enhex {£}) = {%C2%A3}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enhex {元}) = {%E5%85%83}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex {шеллы}) = {%D1%88%D0%B5%D0%BB%D0%BB%D1%8B}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex {!'()*_.-~}) = {!'()*_.-~}") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(enhex {a/b}) = {a%2Fb}") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(enhex %\"a/b?c#d\") = %\"a/b?c#d\"") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex http://a?b=š) = http://a?b=%C5%A1")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex #{C5A1696B}) = #{254335254131696B}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(dehex enhex #{C5A1696B}) = #{C5A1696B}")
    is @value.Logic(true),
  )
}

///|
test "enhex/uri writes a space as plus and encodes a plus sign" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(enhex {a b+}) = {a%20b%2B}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/uri {a b+}) = {a+b%2B}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/uri {a á+}) = {a+%C3%A1%2B}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/uri %\"a b+\") = %\"a+b%2B\"") is @value.Logic(true),
  )
  let other = try {
    @eval.run(env, "enhex/only {a}") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(other)
}

///|
test "enhex/escape uses the given mark, and equals writes uri spaces as underscore" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(enhex/escape {(#)} #\"#\") = {(#23)}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/escape {(š)} #\"#\") = {(#C5#A1)}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/escape {a b_} #\"=\") = {a=20b_}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/uri/escape {a b_} #\"=\") = {a_b=5F}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/escape {a á_} #\"=\") = {a=20=C3=A1_}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/escape/uri {a á_} #\"=\") = {a_=C3=A1=5F}")
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "enhex/escape {a} 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}

///|
test "enhex/except keeps only the characters in the bitset" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(enhex/except {12 ab} charset {12}) = {12%20%61%62}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/except {12 ab} charset {12 }) = {12 %61%62}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/except/escape {(#)} charset {()} #\"#\") = {(#23)}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(enhex/escape/except {(#)} #\"#\" charset {()}) = {(#23)}")
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "enhex/except {a} 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
