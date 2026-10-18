///|
test "a linearized xref stream fills the reference list and the trailer" {
  // codec-pdf.reb decode-xref. W is [1 1 1]. Reading the entries empties the stream.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "p: decode 'pdf #{255044462D312E340A312030206F626A0A3C3C202F4C696E656172697A65642031202F542030203E3E0A656E646F626A0A322030206F626A0A3C3C202F54797065202F58526566202F53697A652032202F526F6F74203320302052202F57205B31203120315D202F4C656E6774682036203E3E0A73747265616D0A0000000110000A656E6473747265616D0A656E646F626A0A2525454F460A} o: select p/objects 2x0 (reduce [p/trailer/Size = 2 p/trailer/Root = 3x0 none? p/trailer/Info none? p/trailer/ID p/referencies = [0x0 0 0 1x0 1 16] o/data = #{}]) = reduce [true true true true true true]",
    )
    is @value.Logic(true),
  )
}
