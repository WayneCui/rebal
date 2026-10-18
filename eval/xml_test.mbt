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

///|
test "xml decode reads the prolog and keeps whitespace text" {
  // codecs-test.r3 XML decode test1 and test2. A declaration after a comment is a processing instruction.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "t1: decode 'xml {<!--inform the XML processor\n  that an external DTD is referenced-->\n<?xml version=\"1.0\" standalone=\"no\" ?>\n\n<!--define the location of the\n  external DTD using a relative URL address-->\n<!DOCTYPE document SYSTEM \"subjects.dtd\">\n\n<document>\n  <title>Subjects available in Mechanical Engineering.</title>\n  <subjectID>2.303</subjectID>\n    <subjectname>Fluid Mechanics</subjectname>\n    <prerequisite>\n      <subjectID>1.001</subjectID>\n      <subjectname>Mathematics</subjectname>\n    </prerequisite>\n    <classes>4 hours per week (lectures and tutorials) for one\n      semester.</classes>\n    <assessment>tutorial assignments and one 2hr exam at end of\n      course.</assessment>\n    <syllabus>\n      Fluid statics. The Bernoulli equation. Energy equation. Momentum\n      equation. Differential Continuity equation. Differential Energy\n      equation. Differential Momentum equation. Dimensional Analysis.\n      Similitude. Laminar flow. Turbulent flow. Lift and Drag. Boundary\n      layer theory.\n    </syllabus>\n    <textbooks>\n      <author>Foobar</author>\n      <booktitle>The Study of Fluid Mechanics</booktitle>\n    </textbooks>\n</document>} t2: decode 'xml {<?xml version=\"1.0\" standalone=\"no\" ?>\n<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\"\n  \"http://www.w3.org/TR/REC-html40/loose.dtd\">\n<HTML>\n<HEAD>\n<TITLE>A typical HTML file</TITLE>\n</HEAD>\n<BODY>\n  This is the typical structure of an HTML file. It follows\n  the notation of the HTML 4.0 specification, including tags\n  that have been deprecated (hence the \"transitional\" label).\n</BODY>\n</HTML>} (reduce [none? t1/document/version none? t1/document/encoding none? t1/document/standalone none? t1/document/pubid none? t1/document/subset (t1/document/doctype) = \"document\" (t1/document/sysid) = \"subjects.dtd\" (length? t1/3) = 1 t1/3/1/1 = \"document\" (length? t1/3/1/3) = 17 (t2/document/version) = \"1.0\" none? t2/document/encoding (t2/document/standalone) = \"no\" (t2/document/doctype) = \"HTML\" (t2/document/pubid) = \"-//W3C//DTD HTML 4.0 Transitional//EN\" (t2/document/sysid) = \"http://www.w3.org/TR/REC-html40/loose.dtd\" none? t2/document/subset (length? t2/3) = 1 t2/3/1/1 = \"HTML\" (length? t2/3/1/3) = 5]) = reduce [true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
