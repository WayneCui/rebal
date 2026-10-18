///|
test "text encode molds values and reads binary as utf-8" {
  // codecs-test.r3 "ENCODE text". A block loses its brackets. /as is ignored.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(encode 'text [1 2]) = {1 2} (encode 'text #{312032}) = {1 2} (encode 'text \"ab\") = {\"ab\"} (encode 'text [a \"b\"]) = {a \"b\"} (encode 'text []) = {} (encode/as 'text [1 2] integer!) = {1 2} (encode 'text #{C3A9}) = {é} (type? try [encode 'text #{FF}]) = error!]) = reduce [true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
