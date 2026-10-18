///|
test "p256 base multiples match the known points" {
  // SEC1 / NIST P-256. Scalars 1, 2, and 3 times the base point.
  match @num.p256_base_mul(hex_bytes("01")) {
    None => assert_true(false)
    Some((x, y)) => {
      assert_eq(
        x,
        hex_bytes(
          "6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296",
        ),
      )
      assert_eq(
        y,
        hex_bytes(
          "4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5",
        ),
      )
    }
  }
  match @num.p256_base_mul(hex_bytes("02")) {
    None => assert_true(false)
    Some((x, y)) => {
      assert_eq(
        x,
        hex_bytes(
          "7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978",
        ),
      )
      assert_eq(
        y,
        hex_bytes(
          "07775510DB8ED040293D9AC69F7430DBBA7DADE63CE982299E04B79D227873D1",
        ),
      )
    }
  }
  match @num.p256_base_mul(hex_bytes("03")) {
    None => assert_true(false)
    Some((x, _)) =>
      assert_eq(
        x,
        hex_bytes(
          "5ECBE4D1A6330A44C8F7EF951D4BF165E6C6B721EFADA985FB41661BC6E7FD6C",
        ),
      )
  }
}

///|
test "p256 shared x is three times the double of the base point" {
  // x(2 * (3*G)) for secp256r1.
  match @num.p256_base_mul(hex_bytes("03")) {
    None => assert_true(false)
    Some((x, y)) =>
      match @num.p256_mul(hex_bytes("02"), x, y) {
        None => assert_true(false)
        Some((sx, _)) =>
          assert_eq(
            sx,
            hex_bytes(
              "B01A172A76A4602C92D3242CB897DDE3024C740DEBB215B4C6B0AAE93C2291A9",
            ),
          )
      }
  }
  assert_true(@num.p256_base_mul(hex_bytes("00")) is None)
  assert_true(!@num.p256_on_curve(hex_bytes("01"), hex_bytes("01")))
}

///|
test "p256 addition doubles the base point and a fixed nonce signs" {
  let gx = hex_bytes(
    "6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296",
  )
  let gy = hex_bytes(
    "4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5",
  )
  match @num.p256_add(gx, gy, gx, gy) {
    None => assert_true(false)
    Some((x, _)) =>
      assert_eq(
        x,
        hex_bytes(
          "7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978",
        ),
      )
  }
  let secret = hex_bytes("03")
  let hash = hex_bytes("01")
  let nonce = hex_bytes("02")
  match @num.p256_sign_rs(secret, hash, nonce) {
    None => assert_true(false)
    Some((r, s)) => {
      assert_eq(
        r,
        hex_bytes(
          "7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978",
        ),
      )
      assert_eq(
        s,
        hex_bytes(
          "3B6BB8A55384F73D4F7B5404870FA825C25AA17CE05F598DFF340818ECE8538C",
        ),
      )
      let px = hex_bytes(
        "5ECBE4D1A6330A44C8F7EF951D4BF165E6C6B721EFADA985FB41661BC6E7FD6C",
      )
      let py = hex_bytes(
        "8734640C4998FF7E374B06CE1A64A2ECD82AB036384FB83D9A79B127A27D5032",
      )
      assert_true(@num.p256_verify_rs(px, py, hash, r, s))
      assert_true(!@num.p256_verify_rs(px, py, hash, r, hex_bytes("03")))
    }
  }
}
