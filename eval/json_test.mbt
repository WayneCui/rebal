///|
test "json decode builds maps and reads unicode escapes" {
  // codecs-test.r3 "JSON codec". "+1" stays a string. "test" becomes a word.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(mold decode 'json {{\"+1\": 1}}) = {make map! [\"+1\" 1]} (select decode 'json {{\"test\": \"\\\"\\u003c\"}} 'test) = {\"<} (decode 'json {true}) = true (decode 'json {false}) = false (decode 'json {null}) = none (decode 'json {[1, \"a\"]}) = [1 \"a\"] (mold decode 'json {{\"b\": {\"c\": 2.0}}}) = {make map! [b make map! [c 2.0]]} (type? try [decode 'json {true,}]) = error!]) = reduce [true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
