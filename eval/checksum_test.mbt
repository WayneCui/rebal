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
