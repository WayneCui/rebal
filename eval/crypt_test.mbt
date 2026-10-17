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
test "crypt rejects a cipher that is not wired yet" {
  let env = @eval.Env::new()
  let missing = try {
    @eval.run(env, "open crypt://aes-128-gcm") |> ignore
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
