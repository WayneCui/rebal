///|
test "a linearized pdf takes its trailer from the T offset" {
  // codec-pdf.reb. The trailer keyword says Size 9. The object at T says Size 2.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "p: decode 'pdf #{255044462D312E340A312030206F626A0A3C3C202F4C696E656172697A65642031202F54203030313133203E3E0A656E646F626A0A322030206F626A0A3C3C202F4C656E6774682035203E3E0A73747265616D0A68656C6C6F0A656E6473747265616D0A656E646F626A0A2525454F460A332030206F626A0A3C3C202F53697A652032202F526F6F74203320302052203E3E0A656E646F626A0A747261696C65720A3C3C202F53697A652039202F526F6F74203120302052203E3E0A7374617274787265660A300A2525454F460A} (reduce [p/version = \"1.4\" p/startxref = 0 p/trailer/Size = 2 p/trailer/Root = 3x0 (select p/objects 1x0)/Linearized = 1 (select p/objects 1x0)/T = 113 (select p/objects 2x0)/data = #{68656C6C6F} (select p/objects 3x0)/Size = 2]) = reduce [true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
