///|
test "checksum crc24 mixes the length into the first byte" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(checksum/method {} 'crc24) = 0") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(checksum/method {a} 'crc24) = 9657536") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum/method {abc} 'crc24) = 1664899") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum/method {123456789} 'crc24) = 12110625")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum/method #{616263} 'crc24) = 1664899")
    is @value.Logic(true),
  )
}

///|
test "checksum crc32 matches the signed 32-bit residue" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(checksum/method {} 'crc32) = 0") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(checksum/method {123456789} 'crc32) = -873187034")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum/method #{313233343536373839} 'crc32) = -873187034")
    is @value.Logic(true),
  )
  let other = try {
    @eval.run(env, "checksum/method {a} 'sha3") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(other)
}

///|
test "checksum adler32 matches the zlib residue" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(checksum/method {} 'adler32) = 1") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum/method {Wikipedia} 'adler32) = 300286872")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum/method #{57696B697065646961} 'adler32) = 300286872")
    is @value.Logic(true),
  )
}

///|
test "checksum sha1 is the 20-byte digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(checksum/method {} 'sha1) = #{DA39A3EE5E6B4B0D3255BFEF95601890AFD80709}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {abc} 'sha1) = #{A9993E364706816ABA3E25717850C26C9CD0D89D}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method #{616263} 'sha1) = #{A9993E364706816ABA3E25717850C26C9CD0D89D}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq} 'sha1) = #{84983E441C3BD26EBAAE4AA1F95129E5E54670F1}",
    )
    is @value.Logic(true),
  )
}

///|
test "checksum md5 is the 16-byte digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(checksum/method {} 'md5) = #{D41D8CD98F00B204E9800998ECF8427E}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {abc} 'md5) = #{900150983CD24FB0D6963F7D28E17F72}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {message digest} 'md5) = #{F96B697D7CB7938D525A2F31AAF161D0}",
    )
    is @value.Logic(true),
  )
}

///|
test "checksum sha256 is the 32-byte digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(checksum/method {} 'sha256) = #{E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {abc} 'sha256) = #{BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq} 'sha256) = #{248D6A61D20638B8E5C026930C3E6039A33CE45964FF2167F6ECEDD419DB06C1}",
    )
    is @value.Logic(true),
  )
}

///|
test "checksum sha512 is the 64-byte digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(checksum/method {} 'sha512) = #{CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {abc} 'sha512) = #{DDAF35A193617ABACC417349AE20413112E6FA4E89A97EA20A9EEEE64B55D39A2192992A274FC1A836BA3C23A3FEEBBD454D4423643CE80E2A9AC94FA54CA49F}",
    )
    is @value.Logic(true),
  )
  let mut sample = "a"
  for _ in 0..<199 {
    sample = sample + "a"
  }
  let source = "(checksum/method {" +
    sample +
    "} 'sha512) = #{4B11459C33F52A22EE8236782714C150A3B2C60994E9ACEE17FE68947A3E6789F31E7668394592DA7BEF827CDDCA88C4E6F86E4DF7ED1AE6CBA71F3E98FAEE9F}"
  assert_true(@eval.run(env, source) is @value.Logic(true))
}

///|
test "checksum sha384 is the first 48 bytes of the wide digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(checksum/method {} 'sha384) = #{38B060A751AC96384CD9327EB1B1E36A21FDB71114BE07434C0CC7BF63F6E1DA274EDEBFE76F65FBD51AD2F14898B95B}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {abc} 'sha384) = #{CB00753F45A35E8BB5A03D699AC65007272C32AB0EDED1631A8B605A43FF5BED8086072BA1E7CC2358BAECA134C825A7}",
    )
    is @value.Logic(true),
  )
  let mut sample = "a"
  for _ in 0..<199 {
    sample = sample + "a"
  }
  let source = "(checksum/method {" +
    sample +
    "} 'sha384) = #{0691B6E978614B67D60557B2A2CDDD53406508522EFA21C624DBBFA8AB6E726D5C586B489C7C09F24109A64C10211D48}"
  assert_true(@eval.run(env, source) is @value.Logic(true))
}

///|
test "checksum/with is HMAC for the digest methods" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(checksum/method/with {Hello world} 'sha1 {mykey}) = #{800A1BC1B53CAA795F4DF39DC57652209239E1F1}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method/with #{48656C6C6F20776F726C64} 'sha1 #{6D796B6579}) = #{800A1BC1B53CAA795F4DF39DC57652209239E1F1}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method/with {Hello world} 'md5 {mykey}) = #{807F6A8C01DCF0D82EDA2DD704291C78}",
    )
    is @value.Logic(true),
  )
  let mut key = ""
  for _ in 0..<70 {
    key = key + "a"
  }
  let folded = "(checksum/method/with {data} 'sha256 {" +
    key +
    "}) = #{5909333A843DAD2C82B27FA55A907F9AB4579EFC3DC96DA5C2D3CD8B80D4E1DF}"
  assert_true(@eval.run(env, folded) is @value.Logic(true))
  let crc = try {
    @eval.run(env, "checksum/method/with {a} 'crc32 {k}") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(crc)
  let other = try {
    @eval.run(env, "checksum/only {a} 'sha1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(other)
}

///|
test "checksum/part limits the hashed bytes" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(checksum/method/part {abc123} 'md5 3) = checksum/method {abc} 'md5")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method/part skip {123abc} 3 'md5 3) = checksum/method {abc} 'md5",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method/part tail {123abc} 'md5 -3) = checksum/method {abc} 'md5",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method/with/part {Hello world!!} 'sha1 {mykey} 11) = checksum/method/with {Hello world} 'sha1 {mykey}",
    )
    is @value.Logic(true),
  )
}

///|
test "checksum sha3 is the keccak digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(checksum/method {} 'sha3-256) = #{A7FFC6F8BF1ED76651C14756A061D662F580FF4DE43B49FA82D80A4B80F8434A}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {abc} 'sha3-256) = #{3A985DA74FE225B2045C172D6BD390BD855F086E3E9D525B46BFE24511431532}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {} 'sha3-224) = #{6B4E03423667DBB73B6E15454F0EB1ABD4597F9A1B078E3F5B5A6BC7}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {} 'sha3-384) = #{0C63A75B845E4F7D01107D852E4C2485C51A50AAAA94FC61995E71BBEE983A2AC3713831264ADB47FB6BD1E058D5F004}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum/method {} 'sha3-512) = #{A69F73CCA23A9AC5C8B567DC185A756E97C982164FE25859E0D1DCC1475C80A615B2123AF1F5F94C11E3E9402C3AC558F500199D95B6D3E301758586281DCD26}",
    )
    is @value.Logic(true),
  )
  let mut sample = ""
  for _ in 0..<200 {
    sample = sample + "a"
  }
  let source = "(checksum/method {" +
    sample +
    "} 'sha3-256) = #{CCE34485BAF2BF2ACA99B94833892A4F52896D3D153F7B840CC4F9FE695F1387}"
  assert_true(@eval.run(env, source) is @value.Logic(true))
  assert_true(
    @eval.run(
      env, "(checksum/method/with {Hello world} 'sha3-256 {mykey}) = #{02ADB5D864627ABC6E9B8D323FB7BF515A03B5C09D3C66DA64974B03B991A57C}",
    )
    is @value.Logic(true),
  )
}
