///|
test "an object stream is unpacked and the stream itself is not kept" {
  // codec-pdf.reb import-objstm. Object 3 sits at offset 0 after First.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "p: decode 'pdf #{255044462D312E340A312030206F626A0A3C3C202F54797065202F436174616C6F67203E3E0A656E646F626A0A322030206F626A0A3C3C202F54797065202F4F626A53746D202F4E2031202F46697273742034202F4C656E6774682038203E3E0A73747265616D0A33203020286869290A656E6473747265616D0A656E646F626A0A2525454F460A} (reduce [(select p/objects 1x0)/Type = 'Catalog none? select p/objects 2x0 (select p/objects 3x0) = \"hi\"]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
}
