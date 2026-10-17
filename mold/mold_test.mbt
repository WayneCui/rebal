///|
test "mold keeps a block loadable" {
  let block = @value.Series::block()
  block.push_item(@value.Integer(1L)) |> ignore
  block.push_item(@value.Char('t'.to_int())) |> ignore
  let text = @mold.mold_text(@value.Seq(block, 0))
  assert_eq(text, "[1 #\"t\"]")
  assert_eq(text.length(), 8)
  assert_eq(@mold.form_text(@value.Seq(block, 0)), "1 t")
}

///|
test "mold and form of the scalar types" {
  assert_eq(@mold.mold_text(@value.None), "none")
  assert_eq(@mold.mold_text(@value.Logic(false)), "false")
  assert_eq(@mold.mold_text(@value.Integer(-3L)), "-3")
  assert_eq(@mold.mold_text(@value.Decimal(1.5)), "1.5")
  assert_eq(@mold.mold_text(@value.Char(0x2190)), "#\"^(2190)\"")
  let word = @value.Sym(@value.SetWord, @value.Lexeme::make(0, "a"))
  assert_eq(@mold.mold_text(word), "a:")
  let refinement = @value.Sym(@value.Refinement, @value.Lexeme::make(1, "foo"))
  assert_eq(@mold.mold_text(refinement), "/foo")
  let quoted = @mold.cell("a\"b")
  assert_eq(@mold.mold_text(quoted), "\"a^\"b\"")
  assert_eq(@mold.form_text(quoted), "a\"b")
  let binary = @value.Series::binary()
  binary.push_byte(0x0A) |> ignore
  assert_eq(@mold.mold_text(@value.Seq(binary, 0)), "#{0A}")
  assert_eq(@mold.type_name(@value.Word), "word!")
}

///|
test "a block that contains itself stops molding" {
  let block = @value.Series::block()
  let cell = @value.Seq(block, 0)
  block.push_item(cell) |> ignore
  let text = @mold.mold_text(cell)
  assert_true(text.length() > 0)
}
