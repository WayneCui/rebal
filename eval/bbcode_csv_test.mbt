///|
test "bbcode csv tags become html tables" {
  // codec-bbcode.reb. The first row is a header. An empty paragraph is removed.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "tab: \"^-\" nl: \"^/\" q: {\"} (reduce [(decode 'bbcode to string! reduce [\"[csv]a\" tab \"b\" nl \"c\" tab \"d\" nl \"[/csv]\"]) = to string! reduce [\"<table>\" nl \"<tr><th>a</th><th>b</th></tr>\" nl \"<tr><td>c</td><td>d</td></tr>\" nl \"</table>\"] (decode 'bbcode to string! reduce [\"[csv divider=\" q \",\" q \"]a,b\" nl \"c,d[/csv]\"]) = to string! reduce [\"<table>\" nl \"<tr><th>a</th><th>b</th></tr>\" nl \"<tr><td>c</td><td>d</td></tr>\" nl \"</table>\"] (decode 'bbcode to string! reduce [\"[csv widths=\" q \"10 20\" q \" class=\" q \"grid\" q \"]h1\" tab \"h2\" nl \"a\" tab \"b[/csv]\"]) = to string! reduce [\"<table class=\" q \"grid\" q \">\" nl \"<tr><th width=10>h1</th><th width=20>h2</th></tr>\" nl \"<tr><td>a</td><td>b</td></tr>\" nl \"</table>\"] (decode 'bbcode to string! reduce [\"[csv coltype=\" q \"cr\" q \"]a\" tab \"b\" nl \"c\" tab \"d[/csv]\"]) = to string! reduce [\"<table>\" nl \"<col align=\" q \"center\" q \">\" nl \"<col align=\" q \"right\" q \">\" nl \"<tr><th>a</th><th>b</th></tr>\" nl \"<tr><td>c</td><td>d</td></tr>\" nl \"</table>\"] (decode 'bbcode to string! reduce [\"before\" nl \"[csv]a\" tab \"b[/csv]\" nl \"after\"]) = to string! reduce [\"<p>before\" nl \"</p><table>\" nl \"<tr><th>a</th><th>b</th></tr>\" nl \"</table>\" nl \"after\"] (decode 'bbcode \"[csv]only[/csv]\") = to string! reduce [\"<table>\" nl \"</table>\"] (decode 'bbcode to string! reduce [\"[csv]a\" tab tab \"c[/csv]\"]) = to string! reduce [\"<table>\" nl \"<tr><th>a</th><th></th><th>c</th></tr>\" nl \"</table>\"] (decode 'bbcode to string! reduce [\"[b][csv]a\" tab \"b[/csv]\"]) = to string! reduce [\"<p><b></b></p><table>\" nl \"<tr><th>a</th><th>b</th></tr>\" nl \"</table>\"]]) = reduce [true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
