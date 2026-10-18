///|
test "handles compare by kind and expose type" {
  // t-handle.c. `=` is the kind. `<` is the kind name. `/type` and
  // `words-of` read the same field that `query` does.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "a: rc4/key #{01} b: rc4/key #{02} c: ecdh/init none 'secp256r1 (reduce [a = b a <> c c < a a > c a/type = 'rc4 c/type = 'ecdh (words-of a) = [type] (query a object!)/type = 'rc4 (query a 'words) = [type] not (a == b)]) = reduce [true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
