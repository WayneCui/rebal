///|
test "crypt aes-128-ecb matches the FIPS-197 block" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-ecb\nmodify port 'key #{000102030405060708090A0B0C0D0E0F}\nmodify port 'init-vector none\ncipher: read write port #{00112233445566778899AABBCCDDEEFF}\nmodify port 'direction 'decrypt\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{69C4E0D86A7B0430D8CDB78070B4C55A} #{00112233445566778899AABBCCDDEEFF}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-128-ecb encrypts each block on its own" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-ecb\nmodify port 'key #{2B7E151628AED2A6ABF7158809CF4F3C}\n(read write port #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}) = #{3AD77BB40D7A3660A89ECAF32466EF97F5D3D58503B9699DE785895A96FDBAAF}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-ecb\nmodify port 'key #{000102030405060708090A0B0C0D0E0F}\nwrite port #{0011223344556677}\nheld: read port\nwrite port #{8899AABBCCDDEEFF}\n(reduce [held read port]) = reduce [none #{69C4E0D86A7B0430D8CDB78070B4C55A}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-256-ecb matches the FIPS-197 block" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-256-ecb\nmodify port 'key #{000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F}\nmodify port 'init-vector none\ncipher: read write port #{00112233445566778899AABBCCDDEEFF}\nmodify port 'direction 'decrypt\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{8EA2B7CA516745BFEAFC49904B496089} #{00112233445566778899AABBCCDDEEFF}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-256-ecb\nmodify port 'key #{603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4}\n(read write port #{6BC1BEE22E409F96E93D7E117393172A}) = #{F3EED1BDB5D2A03C064B5A7E3DB181F8}",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-192-ecb matches the FIPS-197 block" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-192-ecb\nmodify port 'key #{000102030405060708090A0B0C0D0E0F1011121314151617}\nmodify port 'init-vector none\ncipher: read write port #{00112233445566778899AABBCCDDEEFF}\nmodify port 'direction 'decrypt\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{DDA97CA4864CDFE06EAF70A0EC0D7191} #{00112233445566778899AABBCCDDEEFF}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-192-ecb\nmodify port 'key #{8E73B0F7DA0E6452C810F32B809079E562F8EAD2522C6B7B}\n(read write port #{6BC1BEE22E409F96E93D7E117393172A}) = #{BD334F1D6E45F25FF712A214571FA5CC}",
    )
    is @value.Logic(true),
  )
  let short = try {
    @eval.run(
      env, "port: open crypt://aes-192-ecb\nmodify port 'key #{000102030405060708090A0B0C0D0E0F}",
    )
    |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "modify"
        _ => false
      }
  }
  assert_true(short)
}

///|
test "crypt aes-128-cbc chains blocks with the init vector" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-cbc\nmodify port 'key #{2B7E151628AED2A6ABF7158809CF4F3C}\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\ncipher: read write port #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}\nmodify port 'direction 'decrypt\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{7649ABAC8119B246CEE98E9B12E9197D5086CB9B507219EE95DB113A917678B2} #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}]",
    )
    is @value.Logic(true),
  )
  let bare = try {
    @eval.run(
      env, "port: open crypt://aes-128-cbc\nmodify port 'key #{2B7E151628AED2A6ABF7158809CF4F3C}\nwrite port #{6BC1BEE22E409F96E93D7E117393172A}",
    )
    |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "write"
        _ => false
      }
  }
  assert_true(bare)
}

///|
test "crypt aes-192-cbc chains blocks with the init vector" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-192-cbc\nmodify port 'key #{8E73B0F7DA0E6452C810F32B809079E562F8EAD2522C6B7B}\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\ncipher: read write port #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}\nmodify port 'direction 'decrypt\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{4F021DB243BC633D7178183A9FA071E8B4D9ADA9AD7DEDF4E5E738763F69145A} #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-256-cbc chains blocks with the init vector" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-256-cbc\nmodify port 'key #{603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4}\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\ncipher: read write port #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}\nmodify port 'direction 'decrypt\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{F58C4C04D6E5F1BA779EABFB5F7BFBD69CFC4E967EDB808D679F777BC6702C7D} #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt update pads a short AES block with zeros" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-cbc\nmodify port 'key #{2B7E151628AED2A6ABF7158809CF4F3C}\niv: #{000102030405060708090A0B0C0D0E0F}\nmodify port 'init-vector iv\nwrite port #{6BC1BEE22E409F96}\nwrite port #{E93D7E117393172A}\nfull: read port\nmodify port 'init-vector iv\nwrite port #{6BC1BEE22E409F96}\nheld: read port\ncrypted: read update port\nmodify port 'direction 'decrypt\nmodify port 'init-vector iv\nplain: read write port crypted\n(reduce [full held crypted plain read update port take port]) = reduce [#{7649ABAC8119B246CEE98E9B12E9197D} none #{6F8BB83BE51C9A7DE442745E517D4377} #{6BC1BEE22E409F960000000000000000} none none]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "c-port: open crypt://aes-128-cbc\nmodify c-port 'key #{2B7E151628AED2A6ABF7158809CF4F3C}\nmodify c-port 'init-vector #{000102030405060708090A0B0C0D0E0F}\nd-port: open crypt://aes-128-cbc#decrypt\nmodify d-port 'key #{2B7E151628AED2A6ABF7158809CF4F3C}\nmodify d-port 'init-vector #{000102030405060708090A0B0C0D0E0F}\nwrite c-port #{6BC1BEE22E409F96}\nwrite c-port #{E93D7E117393172ADEADBEEF}\nfirst: read c-port\nwrite d-port first\nsecond: take c-port\nwrite d-port second\nplain: take d-port\n(reduce [first second plain]) = reduce [#{7649ABAC8119B246CEE98E9B12E9197D} #{00CA0B3A31A8BD78A2815653B0C4C9DB} #{6BC1BEE22E409F96E93D7E117393172ADEADBEEF000000000000000000000000}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt opens from a spec object" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "p: make port! [scheme: 'crypt algorithm: 'aes-128-cbc]\np/spec/algorithm = 'aes-128-cbc",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open make port! [scheme: 'crypt algorithm: 'aes-128-cbc key: #{2B7E151628AED2A6ABF7158809CF4F3C} init-vector: #{000102030405060708090A0B0C0D0E0F}]\n(read write port #{6BC1BEE22E409F96E93D7E117393172A}) = #{7649ABAC8119B246CEE98E9B12E9197D}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open make port! [scheme: 'crypt algorithm: 'aes-128-ecb direction: 'decrypt key: #{000102030405060708090A0B0C0D0E0F}]\n(read write port #{69C4E0D86A7B0430D8CDB78070B4C55A}) = #{00112233445566778899AABBCCDDEEFF}",
    )
    is @value.Logic(true),
  )
  let missing = try {
    @eval.run(env, "open make port! [scheme: 'crypt]") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "open"
        _ => false
      }
  }
  assert_true(missing)
}

///|
test "crypt camellia-256-ecb matches RFC 3713" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-256-ecb\nmodify port 'key #{0123456789ABCDEFFEDCBA987654321000112233445566778899AABBCCDDEEFF}\ncipher: read write port #{0123456789ABCDEFFEDCBA9876543210}\nmodify port 'direction 'decrypt\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{9ACC237DFF16D76C20EF7C919E3A7509} #{0123456789ABCDEFFEDCBA9876543210}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-256-ecb\nmodify port 'key #{000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F}\n(read write port #{00112233445566778899AABBCCDDEEFF}) = #{2EDF1F3418D53B88841FC8985FB1ECF2}",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt camellia-192-ecb matches RFC 3713" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-192-ecb\nmodify port 'key #{0123456789ABCDEFFEDCBA98765432100011223344556677}\ncipher: read write port #{0123456789ABCDEFFEDCBA9876543210}\nmodify port 'direction 'decrypt\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{B4993401B3E996F84EE5CEE7D79B09B9} #{0123456789ABCDEFFEDCBA9876543210}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-192-ecb\nmodify port 'key #{000102030405060708090A0B0C0D0E0F1011121314151617}\n(read write port #{00112233445566778899AABBCCDDEEFF}) = #{B22F3C36B72D31329EEE8ADDC2906C68}",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt camellia-256-cbc chains blocks with the init vector" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-256-cbc\nmodify port 'key #{603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4}\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\ncipher: read write port #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}\nmodify port 'direction 'decrypt\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{E6CFA35FC02B134A4D2C0B6737AC3EDA36CBEB73BD504B4070B1B7DE2B21EB50} #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt camellia-192-cbc chains blocks with the init vector" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-192-cbc\nmodify port 'key #{8E73B0F7DA0E6452C810F32B809079E562F8EAD2522C6B7B}\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\ncipher: read write port #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}\nmodify port 'direction 'decrypt\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{2A4830AB5AC4A1A2405955FD2195CF935D5A869BD14CE54264F892A6DD2EC3D5} #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt camellia-128-cbc chains blocks with the init vector" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-128-cbc\nmodify port 'key #{2B7E151628AED2A6ABF7158809CF4F3C}\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\ncipher: read write port #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}\nmodify port 'direction 'decrypt\nmodify port 'init-vector #{000102030405060708090A0B0C0D0E0F}\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{1607CF494B36BBF00DAEB0B503C831ABA2F2CF671629EF7840C5A5DFB5074887} #{6BC1BEE22E409F96E93D7E117393172AAE2D8A571E03AC9C9EB76FAC45AF8E51}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt camellia-128-ecb matches RFC 3713" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-128-ecb\nmodify port 'key #{0123456789ABCDEFFEDCBA9876543210}\ncipher: read write port #{0123456789ABCDEFFEDCBA9876543210}\nmodify port 'direction 'decrypt\nplain: read write port cipher\n(reduce [cipher plain]) = reduce [#{67673138549669730857065648EABE43} #{0123456789ABCDEFFEDCBA9876543210}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://camellia-128-ecb\nmodify port 'key #{000102030405060708090A0B0C0D0E0F}\n(read write port #{00112233445566778899AABBCCDDEEFF}) = #{77CF412067AF8270613529149919546F}",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt chacha20 matches the RFC 7539 block" {
  let env = @eval.Env::new()
  let zeros = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
  assert_true(
    @eval.run(
      env,
      "port: open crypt:CHACHA20\nmodify port 'key #{0000000000000000000000000000000000000000000000000000000000000000}\nmodify port 'init-vector #{000000000000000000000000}\n(read write port #{" +
      zeros +
      "}) = #{76B8E0ADA0F13D90405D6AE55386BD28BDD219B8A08DED1AA836EFCC8B770DC7DA41597C5157488D7724E03FB8D84A376A43B8F41518A11CC387B669B2EE6586}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env,
      "port: open crypt://chacha20\nmodify port 'key #{0000000000000000000000000000000000000000000000000000000000000000}\nmodify port 'init-vector #{00000000000000000000000200000000}\n(read write port #{" +
      zeros +
      "}) = #{C2C64D378CD536374AE204B9EF933FCD1A8B2288B3DFA49672AB765B54EE27C78A970E0E955C14F3A88E741B97C286F75F8FC299E8148362FA198A39531BED6D}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://chacha20\nmodify port 'key #{1c9240a5eb55d38af333888604f6b5f0473917c1402b80099dca5cbc207075c0}\nmodify port 'init-vector #{0000000000000000000000020000002A}\nplain: #{2754776173206272696c6c69672c20616e642074686520736c6974687920746f7665730a446964206779726520616e642067696d626c6520696e2074686520776162653a0a416c6c206d696d737920776572652074686520626f726f676f7665732c0a416e6420746865206d6f6d65207261746873206f757467726162652e}\ncipher: read write port plain\nout: open crypt://chacha20#decrypt\nmodify out 'key #{1c9240a5eb55d38af333888604f6b5f0473917c1402b80099dca5cbc207075c0}\nmodify out 'init-vector #{0000000000000000000000020000002A}\nback: read write out cipher\n(reduce [cipher back]) = reduce [#{62e6347f95ed87a45ffae7426f27a1df5fb69110044c0d73118effa95b01e5cf166d3df2d721caf9b21e5fb14c616871fd84c54f9d65b283196c7fe4f60553ebf39c6402c42234e32a356b3e764312a61a5532055716ead6962568f87d3f3f7704c6a8d1bcd1bf4d50d6154b6da731b187b58dfd728afa36757a797ac188d1} plain]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt chacha20 encrypts a short tail in the same write" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://chacha20\nmodify port 'key #{000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f}\nmodify port 'init-vector #{000000000000004a0000000000000001}\nplain: #{4C616469657320616E642047656E746C656D656E206F662074686520636C617373206F66202739393A204966204920636F756C64206F6666657220796F75206F6E6C79206F6E652074697020666F7220746865206675747572652C2073756E73637265656E20776F756C642062652069742E}\ncipher: read write port plain\nout: open crypt://CHACHA20#decrypt\nmodify out 'key #{000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f}\nmodify out 'init-vector #{000000000000004a0000000000000001}\nback: read write out cipher\n(reduce [cipher back]) = reduce [#{6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0bf91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d807ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab77937365af90bbf74a35be6b40b8eedf2785e42874d} plain]",
    )
    is @value.Logic(true),
  )
  let zeros10 = "00000000000000000000"
  let zeros54 = "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
  assert_true(
    @eval.run(
      env,
      "port: open crypt://chacha20\nmodify port 'key #{0000000000000000000000000000000000000000000000000000000000000000}\nmodify port 'init-vector #{000000000000000000000000}\nwrite port #{" +
      zeros10 +
      "}\nheld: read port\nwrite port #{" +
      zeros54 +
      "}\n(reduce [held read port]) = reduce [none #{76B8E0ADA0F13D90405D6AE55386BD28BDD219B8A08DED1AA836EFCC8B770DC7DA41597C5157488D7724E03FB8D84A376A43B8F41518A11CC387B669B2EE6586}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env,
      "port: open crypt://chacha20\nmodify port 'key #{0000000000000000000000000000000000000000000000000000000000000000}\nmodify port 'init-vector #{000000000000000000000000}\nwrite port #{" +
      zeros10 +
      "}\nwrite port #{" +
      zeros10 +
      "}\n(read port) = #{76B8E0ADA0F13D90405D6AE55386BD28}",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt chacha20-poly1305 seals a tls record" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt:chacha20-poly1305\nmodify port 'key #{438D7027FD611C1A5CD532D1151665EA3BB925CF1F37453C109790B604E7A0C4}\nmodify port 'iv #{9F45E14C213A3719186DDF50}\nwrite port #{00000000000000001603030010}\nwrite port #{1400000C89F6A49D54518857D140BE74}\ncipher: read port\nmac: take port\nout: open crypt://chacha20-poly1305#decrypt\nmodify out 'key #{438D7027FD611C1A5CD532D1151665EA3BB925CF1F37453C109790B604E7A0C4}\nmodify out 'iv #{9F45E14C213A3719186DDF50}\nwrite out #{00000000000000001603030010}\nwrite out cipher\nplain: read out\n(reduce [cipher mac plain take out]) = reduce [#{AE84B0499E0B7837027C6FD712A68894} #{3604F4477DCA0C6856559D1DD2EEC03C} #{1400000C89F6A49D54518857D140BE74} mac]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://chacha20-poly1305\nmodify port 'key #{AE8A57A15387FD92E9DAA50FECD6CA31044A7EEC9459EC9C6ED6A93EE4F6CC42}\nmodify port 'iv #{F01A5EF18B11C15FB97AE808}\nwrite port #{00000000000000001603030010000000}\nwrite port #{DEADBEAF}\nwrite port #{0BADCAFE}\n(take port) = #{E3B37D390075D5A09549BA5853B40E0A8368918B7DDD425A}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://chacha20-poly1305\nmodify port 'key #{AE8A57A15387FD92E9DAA50FECD6CA31044A7EEC9459EC9C6ED6A93EE4F6CC42}\nmodify port 'iv #{F01A5EF18B11C15FB97AE808}\nwrite port #{00000000000000001603030010000000}\nwrite port #{DEADBEAF}\nwrite port #{0BADCAFE}\ncipher: read port\nmac: read update port\nout: open crypt://chacha20-poly1305#decrypt\nmodify out 'key #{AE8A57A15387FD92E9DAA50FECD6CA31044A7EEC9459EC9C6ED6A93EE4F6CC42}\nmodify out 'iv #{F01A5EF18B11C15FB97AE808}\nwrite out #{00000000000000001603030010000000}\nwrite out cipher\n(reduce [cipher mac read out read update out]) = reduce [#{E3B37D390075D5A0} #{9549BA5853B40E0A8368918B7DDD425A} #{DEADBEAF0BADCAFE} mac]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-128-ccm appends the tag on write" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-ccm\nmodify port 'key #{C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF}\nmodify port 'iv #{00000003020100A0A1A2A3A4A5}\nmodify port 'tag-length 8\nmodify port 'aad-length 8\nwrite port #{0102030405060708DEADBEAFDEADBEAF}\ncipher: take port\nmodify port 'direction 'decrypt\nwrite port #{01020304050607088E28233EB366D372A7B0AA6A5A3DD56D}\n(reduce [cipher take port]) = reduce [#{8E28233EB366D372A7B0AA6A5A3DD56D} #{DEADBEAFDEADBEAF}]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-ccm\nmodify port 'key #{90929a4b0ac65b350ad1591611fe4829}\nmodify port 'iv #{5a8aa485c316e9403aff859fbb}\nplain: #{4bfe4e35784f0a65b545477e5e2f4bae0e1e6fa717eaf2cb}\ncipher: take write port plain\nmodify port 'direction 'decrypt\nback: take write port cipher\n(reduce [cipher back]) = reduce [#{a16a2e741f1cd9717285b6d882c1fc53655e9773761ad697} plain]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-256-ccm encrypts without a tag" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-256-ccm\nmodify port 'key #{26511fb51fcfa75cb4b44da75a6e5a0eb8d9c8f3b906f886df3ba3e6da3a1389}\nmodify port 'iv #{72a60f345a1978fb40f28a2fa4}\nplain: #{30d56ff2a25b83fee791110fcaea48e41db7c7f098a81000}\ncipher: take write port plain\nmodify port 'direction 'decrypt\nback: take write port cipher\n(reduce [cipher back]) = reduce [#{55f068c0bbba8b598013dd1841fd740fda2902322148ab5e} plain]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-128-gcm authenticates the record" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-gcm\nmodify port 'key #{C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF}\nmodify port 'iv #{00000003020100A0A1A2A3A4A5}\nmodify port 'tag-length 16\nmodify port 'aad-length 13\nwrite port #{00000000000000011703030528}\nwrite port #{DEADBEAFDEADBEAF}\ncipher: read port\ntag: take port\nmodify port 'direction 'decrypt\nwrite port #{00000000000000011703030528}\nwrite port cipher\nplain: read port\n(reduce [cipher tag plain take port]) = reduce [#{E647A20A318C2C9D} #{BF0C5A7A09E536B0234153A2E0EE010A} #{DEADBEAFDEADBEAF} tag]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-gcm\nmodify port 'key #{C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF}\nmodify port 'iv #{00000003020100A0A1A2A3A4A5}\nmodify port 'tag-length 16\nmodify port 'aad-length 4\nwrite port #{decafe00}\nwrite port #{DEADBEAF}\nwrite port #{DEADBEAF}\ncipher: read port\ntag: take port\nmodify port 'direction 'decrypt\nwrite port #{decafe00}\nwrite port cipher\n(reduce [cipher tag read port take port]) = reduce [#{E647A20A318C2C9D} #{834EDE070B5E17D8030223ADD27ACED1} #{DEADBEAFDEADBEAF} tag]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-gcm\nmodify port 'key #{90929a4b0ac65b350ad1591611fe4829}\nmodify port 'iv #{5a8aa485c316e9403aff859fbb}\nplain: #{4bfe4e35784f0a65b545477e5e2f4bae0e1e6fa717eaf2cb}\ncipher: take write port plain\nmodify port 'direction 'decrypt\nback: take write port cipher\n(reduce [cipher back]) = reduce [#{F67D24DEA38559C1AAF75406642EB0D3EE83F18A10E321BF} plain]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-128-gcm tags an empty message" {
  // crypt-port-gcm-test.r3, AES-GCM NIST Validation row 1.
  // A 16-byte nonce is folded with GHASH. The empty write still starts
  // the cipher, so read is #{} and take is only the tag.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-gcm\nmodify port 'key #{1014f74310d1718d1cc8f65f033aaf83}\nmodify port 'iv #{6bb54c9fd83c12f5ba76cc83f7650d2c}\nmodify port 'tag-length 16\nmodify port 'aad-length 0\nwrite port #{}\nwrite port #{}\ncipher: read port\ntag: take port\n(reduce [cipher tag]) = reduce [#{} #{0b6b57db309eff920c8133b8691e0cac}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-128-gcm authenticates a long aad and no plaintext" {
  // crypt-port-gcm-test.r3, AES-GCM NIST Validation row 22.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-gcm\nmodify port 'key #{b5beefbdd23360f2dd1e6e3c1ddbfebf}\nmodify port 'iv #{81a8494f85be635d71e5663789162494}\nmodify port 'tag-length 16\nmodify port 'aad-length 128\nwrite port #{f9ebf242b616a42e2057ede3b56b4c27349fed148817a710654de75d1cfc5f6304709b46ef1e2ccb42f877c50f484f8a8c6b0a25cff61d9537c3fd0c69bbc6ef21cbec8986cbc9b6e87963b8d9db91b7134afe69d3d9dec3a76b6c645f9c5528968f27396cc9e989d589369c90bbfefb249e3fa416451bc3d6592cc5feefbd76}\nwrite port #{}\ncipher: read port\ntag: take port\n(reduce [cipher tag]) = reduce [#{} #{159a642185e0756d46f1db57af975fa3}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-128-gcm encrypts eight blocks from a 16-byte nonce" {
  // crypt-port-gcm-test.r3, AES-GCM NIST Validation row 43.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-gcm\nmodify port 'key #{ce0f8cfe9d64c4f4c045d11b97c2d918}\nmodify port 'iv #{ad4c3627a494fc628316dc03faf81db8}\nmodify port 'tag-length 16\nmodify port 'aad-length 0\nwrite port #{}\nplain: #{dfff250d380f363880963b42d6913c1ba11e8edf7c4ab8b76d79ccbaac628f548ee542f48728a9a2620a0d69339c8291e8d398440d740e310908cdee7c273cc91275ce7271ba12f69237998b07b789b3993aaac8dc4ec1914432a30f5172f79ea0539bd1f70b36d437e5170bc63039a5280816c05e1e41760b58e35696cebd55}\ncipher: read write port plain\ntag: take port\n(reduce [cipher tag]) = reduce [#{0de73d9702d9357c9e8619b7944e40732ac2f4dd3f1b42d8d7f36acb1f1497990d0ec3d626082cdb1384ec72a4c1d98955ba2a3aae6d81b24e9ce533eb5ede7210ae4a06d43f750138b8914d754d43bce416fee799cc4dd03949acedc34def7d6bde6ba41a4cf03d209689a3ad181f1b6dcf76ca25c87eb1c7459cc9f95ddc57} #{5f6a3620e59fe8977286f502d0da7517}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-128-gcm mixes a long header with eight blocks" {
  // crypt-port-gcm-test.r3, AES-GCM NIST Validation row 64.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-gcm\nmodify port 'key #{839664bb6c352e64714254e4d590fb28}\nmodify port 'iv #{5482db71d85039076a541aaba287e7f7}\nmodify port 'tag-length 16\nmodify port 'aad-length 128\nwrite port #{4d75a10ff29414c74d945da046ed45dc02783da28c1ee58b59cbc6f953dd09788b6d513f7366be523e6c2d877c36795942690ce9543050f7ab6f6f647d262360994f7f892e9f59941a8d440619fda8aa20350be14c13d7924c0451c1489da9a0cafd759c3798776245170ad88dbceb3cacde6ba122b656601ccb726e99d54115}\nplain: #{752c7e877663d10f90e5c96cce2686f4aa846a12272a0aba399e860f2838827c7c718365e704084fbe1e68adb27ad18e993c800da2e05bcaf44b651944bde766e7b3ac22f068b525dd0b80b490b3498d7b7199f60faf69fee338087f7a752fb52147034de8922a3ed73b512d9c741f7bac1206e9b0871a970271f50688038ab7}\ncipher: read write port plain\ntag: take port\n(reduce [cipher tag]) = reduce [#{c7ee1c32f8bc0181b53ce57f116e863481db6f21666ba3fa19bd99ce83eee2d573388a0459dfede92e701982a9cc93d697f313062dbea9866526f1d720a128ab97452a35f458637116f7d9294ffc76079539061dfeff9642a049db53d89f2480a6d74a05ff25d46d7048cc16d43f7888b5aff9957b5dc828973afccff63bd42a} #{63c8aa731a60076725cd5f9973eeadb5}]",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-128-ccm matches the first RFC 3610 packet" {
  // crypt-port-ccm-test.r3, RFC 3610 example 1: 23-byte message, 8-byte tag.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-128-ccm\nmodify port 'key #{C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF}\nmodify port 'iv #{00000003020100A0A1A2A3A4A5}\nmodify port 'tag-length 8\nmodify port 'aad-length 8\nwrite port #{000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E}\n(take port) = #{588C979A61C663D2F066D0C2C0F989806D5F6B61DAC38417E8D12CFDF926E0}",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt aes-192-ccm authenticates a 24-byte key" {
  // crypt-port-ccm-test.r3, NIST VTT AES-192, first packet.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "port: open crypt://aes-192-ccm\nmodify port 'key #{11fd45743d946e6d37341fec49947e8c70482494a8f07fcc}\nmodify port 'iv #{c6aeebcb146cfafaae66f78aab}\nmodify port 'tag-length 4\nmodify port 'aad-length 32\nwrite port #{7dc8c52144a7cb65b3e5a846e8fd7eae37bf6996c299b56e49144ebf43a1770fee7e6075ba52846de5d6254959a18affc4faf59c8ef63489}\n(take port) = #{137d9da59baf5cbfd46620c5f298fc766de10ac68e774edf1f2c5bad}",
    )
    is @value.Logic(true),
  )
}

///|
test "crypt rejects a cipher that is not wired yet" {
  let env = @eval.Env::new()
  let missing = try {
    @eval.run(env, "open crypt://aes-128-cfb") |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "open"
        _ => false
      }
  }
  assert_true(missing)
  let early = try {
    @eval.run(
      env, "port: open crypt://aes-128-ecb\nwrite port #{00112233445566778899AABBCCDDEEFF}",
    )
    |> ignore
    false
  } catch {
    error =>
      match error.to_cell() {
        @value.Error(err) => err.id == "cannot" && err.arg1 == "write"
        _ => false
      }
  }
  assert_true(early)
}
