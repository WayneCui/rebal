///|
/// RSASSA-PSS. The salt is one digest long, which is the Mbed TLS default.
fn rsa_pss_sign(
  key : @value.RsaKey,
  data : Array[Int],
  digest : String,
) -> Array[Int]? {
  if key.d.length() == 0 {
    None
  } else {
    let width = unsigned_width(key.n)
    match pss_encode(digest, data, modulus_bits(key.n)) {
      None => None
      Some(encoded) =>
        Some(
          @num.Nat::mod_exp(
            @num.Nat::from_bytes(encoded),
            @num.Nat::from_bytes(key.d),
            @num.Nat::from_bytes(key.n),
          ).be_bytes(width),
        )
    }
  }
}

///|
fn rsa_pss_verify(
  key : @value.RsaKey,
  data : Array[Int],
  signature : Array[Int],
  digest : String,
) -> Bool? {
  let width = unsigned_width(key.n)
  if signature.length() != width {
    Some(false)
  } else {
    let encoded = @num.Nat::mod_exp(
      @num.Nat::from_bytes(signature),
      @num.Nat::from_bytes(key.e),
      @num.Nat::from_bytes(key.n),
    ).be_bytes(width)
    pss_check(digest, data, encoded, modulus_bits(key.n))
  }
}

///|
fn pss_encode(digest : String, data : Array[Int], bits : Int) -> Array[Int]? {
  let hlen = hash_len(digest)
  let em_bits = bits - 1
  let em_len = (em_bits + 7) / 8
  if hlen == 0 || em_len < hlen + hlen + 2 {
    None
  } else {
    let salt = random_span(hlen)
    let mixed = pss_digest(digest, data, salt)
    let db = pss_block(em_len, hlen, salt)
    let masked = xor_bytes(db, mgf1(digest, mixed, em_len - hlen - 1))
    clear_top(masked, 8 * em_len - em_bits)
    Some(join_span(join_span(masked, mixed), [0xBC]))
  }
}

///|
fn pss_check(
  digest : String,
  data : Array[Int],
  encoded : Array[Int],
  bits : Int,
) -> Bool? {
  let hlen = hash_len(digest)
  let em_bits = bits - 1
  let em_len = (em_bits + 7) / 8
  if hlen == 0 || em_len < hlen + hlen + 2 || encoded.length() != em_len {
    None
  } else if encoded[em_len - 1] != 0xBC {
    Some(false)
  } else {
    let masked = span_bytes(encoded, 0, em_len - hlen - 1)
    let mixed = span_bytes(encoded, em_len - hlen - 1, hlen)
    let db = xor_bytes(masked, mgf1(digest, mixed, masked.length()))
    clear_top(db, 8 * em_len - em_bits)
    match pss_salt(db, hlen) {
      None => Some(false)
      Some(salt) => Some(same_bytes(pss_digest(digest, data, salt), mixed))
    }
  }
}

///|
fn pss_digest(
  digest : String,
  data : Array[Int],
  salt : Array[Int],
) -> Array[Int] {
  let prefix = [0, 0, 0, 0, 0, 0, 0, 0]
  hash_bytes(
    digest,
    join_span(join_span(prefix, hash_bytes(digest, data)), salt),
  )
}

///|
fn pss_block(em_len : Int, hlen : Int, salt : Array[Int]) -> Array[Int] {
  let db : Array[Int] = []
  let mut pad = em_len - hlen - hlen - 2
  while pad > 0 {
    db.push(0)
    pad = pad - 1
  }
  db.push(0x01)
  join_span(db, salt)
}

///|
fn pss_salt(db : Array[Int], hlen : Int) -> Array[Int]? {
  let mut index = 0
  while index < db.length() && db[index] == 0 {
    index = index + 1
  }
  if index >= db.length() || db[index] != 1 {
    None
  } else if db.length() - index - 1 != hlen {
    None
  } else {
    Some(span_bytes(db, index + 1, hlen))
  }
}

///|
fn modulus_bits(bytes : Array[Int]) -> Int {
  let mut index = 0
  while index < bytes.length() && bytes[index] == 0 {
    index = index + 1
  }
  if index == bytes.length() {
    0
  } else {
    let mut top = bytes[index]
    let mut bits = 0
    while top > 0 {
      bits = bits + 1
      top = top / 2
    }
    bits + (bytes.length() - index - 1) * 8
  }
}

///|
fn clear_top(bytes : Array[Int], bits : Int) -> Unit {
  if bits > 0 && bytes.length() > 0 {
    bytes[0] = bytes[0] & (0xFF >> bits)
  }
}
