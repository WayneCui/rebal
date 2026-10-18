///|
test "html-entities turns names and numbers into characters" {
  // codecs-test.r3 "decode html-entities".
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(decode 'html-entities {Test: &spades; & &#162; &lt;a&gt;&#32;and &Delta;&delta; &frac34;}) = {Test: ♠ & ¢ <a> and Δδ ¾} (decode 'html-entities #{546573743A20267370616465733B20262026233136323B20266C743B612667743B262333323B616E64202644656C74613B2664656C74613B20266672616333343B}) = {Test: ♠ & ¢ <a> and Δδ ¾} (decode 'html-entities {&#x00C9;mily}) = {Émily} (decode 'html-entities {&#x0C9;mily}) = {Émily} (decode 'html-entities {&#xC9;mily}) = {Émily} (decode 'html-entities {&#xFFFFFF; & &#1114112;}) = {&#xFFFFFF; & &#1114112;}]) = reduce [true true true true true true]",
    )
    is @value.Logic(true),
  )
}
