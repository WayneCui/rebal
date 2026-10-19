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
}
