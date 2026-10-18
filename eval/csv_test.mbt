///|
test "csv quotes strings and tsv uses tabs" {
  // codec-csv.reb. none is an empty field. Decode keeps every field a string.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "row: reduce [reduce [1 \"a,b\" none]] (reduce [(encode 'csv row) = \"1,^\"a,b^\",^/\" (decode 'csv \"1,^\"a,b^\",^/2,x^/\") = [[\"1\" \"a,b\" \"\"] [\"2\" \"x\"]] (encode 'tsv [[1 \"ab\"]]) = \"1^-^\"ab^\"^/\" (decode 'tsv \"1^-ab^/\") = [[\"1\" \"ab\"]] (decode 'csv \"\") = [] (decode 'csv \"^/\") = [[\"\"]] (load save %/tmp/rebal-v.csv [[1 \"a\"]]) = [[\"1\" \"a\"]] (encode 'csv [[1.5 $2.5 1-Jan-2020]]) = \"1.5,2.5,2020-01-01^/\" (type? try [encode 'csv true]) = error!]) = reduce [true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
