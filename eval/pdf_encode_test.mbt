///|
test "pdf encode writes the catalog bytes r3 writes" {
  // codec-pdf.reb encode. No info dictionary, so the bytes do not depend on now.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "pdf: make object! [version: \"1.4\" objects: make map! reduce [1x0 make map! [Type: Catalog Pages: 2x0] 2x0 make map! [Type: Pages Count: 0 Kids: []]] trailer: make map! [Root: 1x0]] bin: encode 'pdf pdf back: decode 'pdf bin (reduce [bin = #{255044462D312E340D25E2E3CFD30D0A312030206F626A0D3C3C2F547970652F436174616C6F672F50616765732032203020523E3E0D656E646F626A0D322030206F626A0D3C3C2F547970652F50616765732F436F756E7420302F4B6964735B5D3E3E0D656E646F626A0D787265660D0A3020330D0A3030303030303030303020363535333520660D0A30303030303030303136203030303030206E0D0A30303030303030303631203030303030206E0D0A747261696C65720D0A3C3C2F526F6F742031203020523E3E0D0A7374617274787265660D0A3130370D0A2525454F460D0A} back/version = \"1.4\" back/startxref = 107 back/trailer/Root = 1x0 (select back/objects 1x0)/Type = 'Catalog (select back/objects 2x0)/Count = 0 none? encode 'pdf make object! [version: \"1.4\"] none? encode 'pdf make object! [version: \"nope\" objects: make map! []]]) = reduce [true true true true true true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "pdf: make object! [version: \"1.4\" objects: make map! reduce [1x0 make map! [Type: Catalog] 2x0 make object! [spec: make map! [Length: 5] data: #{68656C6C6F}]] trailer: make map! [Root: 1x0]] back: decode 'pdf encode 'pdf pdf stream: select back/objects 2x0 (reduce [stream/spec/Length = 5 stream/data = #{68656C6C6F}]) = reduce [true true]",
    )
    is @value.Logic(true),
  )
}
