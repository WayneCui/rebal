///|
test "xml decode builds a document block and expands entities" {
  // codecs-test.r3 "XML decode test3". Attributes and text share HTML entities.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(decode 'xml {<a name=\"&#x00C9;mily\">&#xC9;mily &spades;</a>}) = reduce ['document make map! [] reduce [reduce [\"a\" reduce [\"name\" \"Émily\"] reduce [\"Émily ♠\"]]]] (decode 'xml {<b/>}) = reduce ['document make map! [] reduce [reduce [\"b\" none none]]] (decode 'xml {<a>x<b/></a>}) = reduce ['document make map! [] reduce [reduce [\"a\" none reduce [\"x\" reduce [\"b\" none none]]]]] (select pick decode 'xml {<?xml version=\"1.0\"?><b/>} 2 'version) = \"1.0\" (type? try [decode 'xml {<a>}]) = error!]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}
