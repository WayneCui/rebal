///|
test "css tokens keep numbers and whitespace until the end" {
  // codec-css.reb. A computed keep is appended after the input keeps.
  // Minify then moves `{` the same way, and `black` becomes #000.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "a: decode 'css #{617B636F6C6F723A7265647D} b: decode 'css #{6831207B20636F6C6F723A20626C61636B3B207D} write %/tmp/rebal-sheet.css {a{color:red}} save %/tmp/rebal-min.css a (reduce [a = [#\"a\" #\"{\" \"color\" #\":\" \"red\" #\"}\"] (encode 'css a) = \"acolor:red}{\" (encode 'css b) = \"h1color:  {#000}\" (decode 'css #{2E35656D}) = [\"em\" 0.5] (encode 'css decode 'css #{306D73}) = \"ms0\" (decode 'css #{2F2A632A2F61}) = [#\"a\"] (decode 'css #{C3A9}) = [#\"é\"] (decode 'css #{}) = [] (encode 'css []) = \"\" (encode 'css [0 \"ms\"]) = \"0s\" (encode 'css [\"Black\"]) = \"#000\" (encode 'css [#\"-\" 0.0]) = \"0.0\" (encode 'css [#\"+\" 1]) = \"1\" (encode 'css [1 #\" \" #\"/\" #\" \" 2]) = \"1 / 2\" (load %/tmp/rebal-sheet.css) = a (load %/tmp/rebal-min.CSS) = decode 'css #{61636F6C6F723A7265647D7B} ((try [decode 'css \"a\"])/id) = 'expect-arg ((try [decode 'css \"a\"])/arg1) = \"decode\" ((try [encode 'css \"a\"])/id) = 'expect-arg ((try [decode 'css #{FF}])/id) = 'invalid-utf (decode 'css #{EFBBBF61}) = [#\"a\"]]) = reduce [true true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
