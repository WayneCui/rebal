///|
fn hex_bytes(text : String) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index + 1 < text.length() {
    let hi = hex_nibble(text[index].to_int())
    let lo = hex_nibble(text[index + 1].to_int())
    out.push(hi * 16 + lo)
    index = index + 2
  }
  out
}

///|
fn hex_nibble(code : Int) -> Int {
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 97 && code <= 102 {
    code - 87
  } else {
    code - 55
  }
}

///|
test "two to the tenth modulo one thousand is twenty-four" {
  let got = @num.Nat::mod_exp(
    @num.Nat::from_bytes([2]),
    @num.Nat::from_bytes([10]),
    @num.Nat::from_bytes([0x03, 0xE8]),
  )
  assert_eq(got.be_bytes(2), [0, 24])
}

///|
test "a mid sized power matches the residue" {
  // pow(123456789, 98765, 10**9+7) = 486973100
  let got = @num.Nat::mod_exp(
    @num.Nat::from_bytes([0x07, 0x5B, 0xCD, 0x15]),
    @num.Nat::from_bytes([0x01, 0x81, 0xCD]),
    @num.Nat::from_bytes([0x3B, 0x9A, 0xCA, 0x07]),
  )
  assert_eq(got.be_bytes(4), [0x1D, 0x06, 0x9E, 0xAC])
}

///|
test "remainder keeps the low part of a longer magnitude" {
  let left = @num.Nat::from_bytes(
    hex_bytes(
      "ed22b370e96e0f9ca57a2b88214607345dd2a3a0591effcc152a1bb891f6f764cd8293d0c9ceeffc",
    ),
  )
  let right = @num.Nat::from_bytes(
    hex_bytes("da8b6881266714bdb20380b9fe5fac750a7b98f1d657442d"),
  )
  let got = left.remainder(right)
  assert_eq(
    got.be_bytes(24),
    hex_bytes("c6f5e5f807e05077f72bdf759dce8cbd81f79eb60bfdec3c"),
  )
}

///|
test "a 32-byte power matches the residue" {
  let got = @num.Nat::mod_exp(
    @num.Nat::from_bytes(
      hex_bytes(
        "1350494e6f7c055a8b6881266714bdb20380b9fe5fac750a7b98f1d657442d62",
      ),
    ),
    @num.Nat::from_bytes(hex_bytes("80b9fe5f")),
    @num.Nat::from_bytes(
      hex_bytes(
        "a6e7943d328300397edf2cf58afb187156d7c4ade27330a92ecf5c653aeb48e1",
      ),
    ),
  )
  assert_eq(
    got.be_bytes(32),
    hex_bytes(
      "47cf20eeab5438dd1ac5a92feef85fa6bf2e647c904eeb5e6fbea5239c70c223",
    ),
  )
}

///|
test "a smaller same-width value is already its remainder" {
  let modulus = hex_bytes(
    "FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF",
  )
  let value = hex_bytes(
    "FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFD",
  )
  let got = @num.Nat::from_bytes(value).remainder(@num.Nat::from_bytes(modulus))
  assert_eq(got.be_bytes(32), value)
}
