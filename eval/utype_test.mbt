///|
test "utype make accepts two blocks and never compares equal" {
  // t-utype.c. The body is not evaluated. Mold is the type name, form wraps
  // it in question marks, and a value is not equal to itself.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "a: make utype! [[] []] b: make utype! [[] [a: 1]] (reduce [(mold a) = {utype!} (form a) = {?utype!?} (mold/all a) = {#(utype!)} (type? a) = utype! not a = a not a == a not a = b ((try [words-of a])/id) = 'expect-arg ((try [a/title])/id) = 'bad-path-type ((try [make utype! none])/id) = 'invalid-arg ((try [make utype! []])/id) = 'invalid-arg ((try [make utype! [[]]])/id) = 'invalid-arg ((try [make utype! [1 2]])/id) = 'invalid-arg ((try [make utype! [a []]])/id) = 'invalid-arg ((try [make utype! [[] a]])/id) = 'invalid-arg find any-type! utype!]) = reduce [true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
