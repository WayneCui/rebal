///|
test "make copies an object and keeps a new block to itself" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "a: make object! [m: make map! [a: 1] b: [1] n: 2] c: make a [n: 4 z: 5] c/m/a: 9 append c/b 2 (reduce [a/m/a = 9 (mold a/b) = {[1]} a/n = 2 c/n = 4 c/z = 5 (words-of c) = [m b n z] (words-of a) = [m b n]]) = reduce [true true true true true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "p: make object! [uid: none] q: make p [] q/uid: 1 (reduce [(type? q) = object! none? p/uid q/uid = 1]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "make p 1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
  assert_true(
    @eval.run(
      env, "o: make object! [a: 1 b: none] (reduce [(select o 'a) = 1 none? select o 'b none? select o 'z none? select o 1]) = reduce [true true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "o: make object! [a: 1 me: does [self]] (reduce [same? o o/me (words-of o) = [a me] none? select o 'self]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
  let path_self = try {
    @eval.run(env, "o/self") |> ignore
    false
  } catch {
    error => error.id() == "invalid-path"
  }
  assert_true(path_self)
  let set_self = try {
    @eval.run(env, "o/self: 1") |> ignore
    false
  } catch {
    error => error.id() == "invalid-path"
  }
  assert_true(set_self)
  assert_true(
    @eval.run(
      env, "c: make o [] (reduce [same? c c/me not same? c o (words-of c) = [a me]]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "put writes a map, an object field, and a block key" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "m: make map! [] (reduce [(put m 'a 1) = 1 (select m 'a) = 1 (put m \"b\" 2) = 2 (select m \"b\") = 2]) = reduce [true true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "o: make object! [a: 1] (reduce [(put o 'a 5) = 5 o/a = 5]) = reduce [true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "b: [a 1] (reduce [(put b 'a 9) = 9 b/a = 9]) = reduce [true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "e: make object! [] (reduce [(put e 'x 1) = 1 e/x = 1 (words-of e) = [x]]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "b2: [a 1] (reduce [(put b2 'c 9) = 9 b2 = [a 1 c 9]]) = reduce [true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "m: make map! [a: 1] c: copy m c/a: 2 (reduce [(select m 'a) = 1 (select c 'a) = 2 not same? m c]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "k: 'a m: make map! [a: 1] (reduce [m/:k = 1 (m/:k: 9 m/a) = 9]) = reduce [true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "a later object does not rebind an older method's nested locals" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "make-list: func [] [make object! [n: 0 bump: func [/local idx] [n: n + 1 idx: n make object! compose/deep [i: (idx) f: func [] [i]]]]] l1: make-list l2: make-list w1: l1/bump w2: l2/bump w3: l1/bump (reduce [w1/i = 1 w2/i = 1 w3/i = 2 w1/f = 1 w3/f = 2 l1/n = 2 l2/n = 1]) = reduce [true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
