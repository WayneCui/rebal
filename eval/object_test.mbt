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
