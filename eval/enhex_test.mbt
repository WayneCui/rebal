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
