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
    @eval.run(env, "checksum {a} 'sha1") |> ignore
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
