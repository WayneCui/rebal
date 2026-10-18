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

///|
test "json encode writes maps without spaces and round-trips" {
  // codecs-test.r3 "JSON encode/decode". The string is newline then tab.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "data: make map! reduce ['a 1 'b make map! reduce ['c 2.0] 'd \"^/^-\"] (reduce [(encode 'json data) = {{\"a\":1,\"b\":{\"c\":2.0},\"d\":\"\\n\\t\"}} (decode 'json encode 'json data) = data (encode 'json true) = {true} (encode 'json none) = {null} (encode 'json []) = {[]} (encode 'json make map! []) = {{}} (encode 'json [1 \"a\"]) = {[1,\"a\"]} (encode 'json \"^G\") = {\"\\u0007\"} (encode 'json make map! [\"+1\" 1]) = {{\"+1\":1}}]) = reduce [true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "json encode writes object fields in creation order" {
  // codec-json.reb. object! uses the same object text as map!.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(encode 'json make object! [b: 2 a: 1]) = {{\"b\":2,\"a\":1}} (encode 'json make object! [a: none b: true]) = {{\"a\":null,\"b\":true}} (encode 'json make object! [a: make object! [c: 3]]) = {{\"a\":{\"c\":3}}} (encode 'json make object! []) = {{}} (encode 'json make object! [a: 'hi]) = {{\"a\":\"hi\"}}]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}
