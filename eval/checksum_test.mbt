///|
test "checksum crc32 matches the signed 32-bit residue" {
  let env = @eval.Env::new()
  assert_true(@eval.run(env, "(checksum {} 'crc32) = 0") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(checksum {123456789} 'crc32) = -873187034")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum #{313233343536373839} 'crc32) = -873187034")
    is @value.Logic(true),
  )
  let other = try {
    @eval.run(env, "checksum {a} 'sha512") |> ignore
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
    @eval.run(env, "(checksum {} 'adler32) = 1") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum {Wikipedia} 'adler32) = 300286872")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(checksum #{57696B697065646961} 'adler32) = 300286872")
    is @value.Logic(true),
  )
}

///|
test "checksum sha1 is the 20-byte digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(checksum {} 'sha1) = #{DA39A3EE5E6B4B0D3255BFEF95601890AFD80709}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum {abc} 'sha1) = #{A9993E364706816ABA3E25717850C26C9CD0D89D}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum #{616263} 'sha1) = #{A9993E364706816ABA3E25717850C26C9CD0D89D}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum {abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq} 'sha1) = #{84983E441C3BD26EBAAE4AA1F95129E5E54670F1}",
    )
    is @value.Logic(true),
  )
}

///|
test "checksum md5 is the 16-byte digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(checksum {} 'md5) = #{D41D8CD98F00B204E9800998ECF8427E}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum {abc} 'md5) = #{900150983CD24FB0D6963F7D28E17F72}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum {message digest} 'md5) = #{F96B697D7CB7938D525A2F31AAF161D0}",
    )
    is @value.Logic(true),
  )
}

///|
test "checksum sha256 is the 32-byte digest" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(checksum {} 'sha256) = #{E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum {abc} 'sha256) = #{BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(checksum {abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq} 'sha256) = #{248D6A61D20638B8E5C026930C3E6039A33CE45964FF2167F6ECEDD419DB06C1}",
    )
    is @value.Logic(true),
  )
}
