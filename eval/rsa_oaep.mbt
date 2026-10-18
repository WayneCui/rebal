///|
/// RSAES-OAEP with an empty label. The mask function is MGF1 over `digest`.
fn rsa_oaep_encrypt(
  key : @value.RsaKey,
  data : Array[Int],
  digest : String,
) -> Array[Int]? {
  let width = unsigned_width(key.n)
  match oaep_encode(digest, data, width) {
    None => None
    Some(encoded) =>
      Some(
        @num.Nat::mod_exp(
          @num.Nat::from_bytes(encoded),
          @num.Nat::from_bytes(key.e),
          @num.Nat::from_bytes(key.n),
        ).be_bytes(width),
      )
  }
}

///|
fn rsa_oaep_decrypt(
  key : @value.RsaKey,
  cipher : Array[Int],
  digest : String,
) -> Array[Int]? {
  let width = unsigned_width(key.n)
  if key.d.length() == 0 || cipher.length() != width {
    None
  } else {
    oaep_decode(
      digest,
      @num.Nat::mod_exp(
        @num.Nat::from_bytes(cipher),
        @num.Nat::from_bytes(key.d),
        @num.Nat::from_bytes(key.n),
      ).be_bytes(width),
    )
  }
}

///|
fn oaep_encode(
  digest : String,
  message : Array[Int],
  width : Int,
) -> Array[Int]? {
  let hlen = hash_len(digest)
  if hlen == 0 || message.length() > width - 2 * hlen - 2 {
    None
  } else {
    let seed = random_span(hlen)
    let db = oaep_data(digest, message, width)
    let masked_db = xor_bytes(db, mgf1(digest, seed, width - hlen - 1))
    let masked_seed = xor_bytes(seed, mgf1(digest, masked_db, hlen))
    Some(join_span([0x00], join_span(masked_seed, masked_db)))
  }
}

///|
fn oaep_decode(digest : String, encoded : Array[Int]) -> Array[Int]? {
  let hlen = hash_len(digest)
  if hlen == 0 || encoded.length() < 2 * hlen + 2 || encoded[0] != 0 {
    None
  } else {
    let masked_seed = span_bytes(encoded, 1, hlen)
    let masked_db = span_bytes(encoded, 1 + hlen, encoded.length() - hlen - 1)
    let seed = xor_bytes(masked_seed, mgf1(digest, masked_db, hlen))
    let db = xor_bytes(
      masked_db,
      mgf1(digest, seed, encoded.length() - hlen - 1),
    )
    oaep_message(digest, db)
  }
}

///|
fn oaep_data(digest : String, message : Array[Int], width : Int) -> Array[Int] {
  let hlen = hash_len(digest)
  let db = hash_bytes(digest, [])
  let mut pad = width - message.length() - 2 * hlen - 2
  while pad > 0 {
    db.push(0)
    pad = pad - 1
  }
  db.push(0x01)
  join_span(db, message)
}

///|
fn oaep_message(digest : String, db : Array[Int]) -> Array[Int]? {
  let label = hash_bytes(digest, [])
  if db.length() < label.length() + 1 ||
    !same_bytes(span_bytes(db, 0, label.length()), label) {
    None
  } else {
    let mut index = label.length()
    while index < db.length() && db[index] == 0 {
      index = index + 1
    }
    if index >= db.length() || db[index] != 1 {
      None
    } else {
      Some(span_bytes(db, index + 1, db.length() - index - 1))
    }
  }
}

///|
fn mgf1(digest : String, seed : Array[Int], length : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut counter = 0
  while out.length() < length {
    let block = hash_bytes(digest, join_span(seed, counter_bytes(counter)))
    let mut index = 0
    while index < block.length() && out.length() < length {
      out.push(block[index])
      index = index + 1
    }
    counter = counter + 1
  }
  out
}

///|
fn counter_bytes(counter : Int) -> Array[Int] {
  [
    (counter >> 24) & 0xFF,
    (counter >> 16) & 0xFF,
    (counter >> 8) & 0xFF,
    counter & 0xFF,
  ]
}

///|
fn hash_len(digest : String) -> Int {
  if digest == "md5" {
    16
  } else if digest == "sha1" {
    20
  } else if digest == "sha384" {
    48
  } else if digest == "sha512" {
    64
  } else if digest == "sha256" {
    32
  } else {
    0
  }
}

///|
fn hash_bytes(digest : String, data : Array[Int]) -> Array[Int] {
  if digest == "md5" {
    md5(data)
  } else if digest == "sha1" {
    sha1(data)
  } else if digest == "sha384" {
    sha384(data)
  } else if digest == "sha512" {
    sha512(data)
  } else {
    sha256(data)
  }
}

///|
fn random_span(count : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index < count {
    out.push(c_random_byte())
    index = index + 1
  }
  out
}

///|
fn xor_bytes(left : Array[Int], right : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index < left.length() && index < right.length() {
    out.push(left[index] ^ right[index])
    index = index + 1
  }
  out
}

///|
fn join_span(left : Array[Int], right : Array[Int]) -> Array[Int] {
  left + right
}

///|
fn span_bytes(bytes : Array[Int], start : Int, count : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index < count {
    out.push(bytes[start + index])
    index = index + 1
  }
  out
}
