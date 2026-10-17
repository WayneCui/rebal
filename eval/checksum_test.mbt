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
    @eval.run(env, "checksum {a} 'md5") |> ignore
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
