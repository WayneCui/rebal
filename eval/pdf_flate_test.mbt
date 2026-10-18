///|
test "a flate xref stream is inflated before its entries are read" {
  // codec-pdf.reb decompress-obj. Two header bytes come off, then raw deflate.
  // Length becomes the inflated size and the filter is cleared.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "p: decode 'pdf #{255044462D312E340A312030206F626A0A3C3C202F4C696E656172697A65642031202F542030203E3E0A656E646F626A0A322030206F626A0A3C3C202F54797065202F58526566202F53697A652032202F526F6F74203320302052202F57205B31203120315D202F46696C746572202F466C6174654465636F6465202F4C656E677468203134203E3E0A73747265616D0A789C6360606014600000002900120A656E6473747265616D0A656E646F626A0A2525454F460A} o: select p/objects 2x0 (reduce [p/referencies = [0x0 0 0 1x0 1 16] p/trailer/Size = 2 p/trailer/Root = 3x0 o/spec/Length = 6 none? o/spec/Filter o/data = #{}]) = reduce [true true true true true true]",
    )
    is @value.Logic(true),
  )
}
