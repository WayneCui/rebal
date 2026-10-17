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
test "crypt aes-128-ecb rejects a different algorithm" {
  let env = @eval.Env::new()
  let missing = try {
    @eval.run(env, "open crypt://aes-192-ecb") |> ignore
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
