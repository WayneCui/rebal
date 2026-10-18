///|
test "bbcode wraps text and leaves alias tags open until the end" {
  // codec-bbcode.reb. quote records fieldset, not the name quote, so the
  // written close does not end the element.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "write %/tmp/rebal-note.bbcode {[b]x[/b]} (reduce [(decode 'bbcode {hello}) = {<p>hello</p>} (decode 'bbcode {[b]x[/b]}) = {<p><b>x</b></p>} (decode 'bbcode {[i]a[/i][u]b[/u]}) = {<p><i>a</i><u>b</u></p>} (decode 'bbcode {[url]http://a[/url]}) = {<p><a href=\"http://a\">http://a</a></p>} (decode 'bbcode {[br]}) = {<p><br></p>} (decode 'bbcode {[hr]}) = {<p><hr></p>} (decode 'bbcode {[hr 50%]}) = {<p><hr style=\"width:50%\"></p>} (decode 'bbcode \"a^/^/b\") = \"<p>a</p>^/^/<p>b</p>\" (decode 'bbcode {[quote]hi[/quote]}) = {<p><fieldset><blockquote>hi</blockquote></fieldset></p>} (decode 'bbcode {[quote=Ada]hi[/quote]there}) = {<p><fieldset><legend>Ada</legend><blockquote>hithere</blockquote></fieldset></p>} (decode 'bbcode {[color=#fff]x[/color]y}) = {<p><span style=\"color: #fff;\">xy</span></p>} (decode 'bbcode {[list][*]a[*]b[/list]}) = {<ul><li>a</li><li>b</li></ul>} (decode 'bbcode {[code]1 < 2[/code]}) = {<p><code>1 < 2</code></p>} (decode 'bbcode {a < b}) = {<p>a &lt; b</p>} (decode 'bbcode {[b]x}) = {<p><b>x</b></p>} (decode 'bbcode {[h1]t[/h1]}) = {<h1>t</h1>} (decode 'bbcode {}) = {<p></p>} (decode 'bbcode {[nope]x[/nope]}) = {<p>[nope]x</p>} (load %/tmp/rebal-note.bbcode) = {<p><b>x</b></p>} ((try [save %/tmp/rebal-note.bbcode {hi}])/id) = 'not-done]) = reduce [true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
