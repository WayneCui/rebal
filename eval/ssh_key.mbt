///|
/// `decode 'ssh-key`. An `ssh-rsa` blob becomes `#(handle! rsa)`.
/// Anything else is the codec dispatcher's `no-codec` error: the Rebol
/// decoder returns `none`, and `decode` turns that into an error.
fn decode_ssh_key(
  env : Env,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let bytes = payload_bytes(value, "decode")
  match read_pem(latin_text(bytes)) {
    Some(pem) =>
      if pem.label == "SSH2 PUBLIC KEY" {
        rsa_handle(pem.bytes)
      } else if pem.label == "RSA PRIVATE KEY" {
        rsa_private_handle(env, pem.bytes)
      } else if pem.label == "PRIVATE KEY" {
        pkcs8_private_handle(env, pem.bytes)
      } else {
        raise EvalError::Caused("no-codec", "ssh-key")
      }
    None => rsa_handle(ssh_payload(bytes))
  }
}

///|
fn ssh_payload(bytes : Array[Int]) -> Array[Int] raise EvalError {
  let text = latin_text(bytes)
  if has_prefix(text, "ssh-rsa ") {
    let mut end = 8
    while end < text.length() && text[end].to_int() != 32 {
      end = end + 1
    }
    decode_base64(text[8:end].to_owned()) catch {
      _ => raise EvalError::Caused("no-codec", "ssh-key")
    }
  } else {
    bytes
  }
}

///|
fn rsa_handle(bytes : Array[Int]) -> @value.Cell raise EvalError {
  match ssh_parts(bytes) {
    Some(parts) =>
      if latin_text(parts.0) == "ssh-rsa" {
        match @value.RsaKey::new(parts.2, parts.1) {
          Some(key) => @value.Handle(key)
          None => raise EvalError::Caused("no-codec", "ssh-key")
        }
      } else {
        raise EvalError::Caused("no-codec", "ssh-key")
      }
    None => raise EvalError::Caused("no-codec", "ssh-key")
  }
}

///|
/// PKCS#8 `PRIVATE KEY`: an rsaEncryption id wrapped around a PKCS#1 key.
fn pkcs8_private_handle(
  env : Env,
  bytes : Array[Int],
) -> @value.Cell raise EvalError {
  match pkcs8_key_bytes(env, bytes) {
    Some(inner) => rsa_private_handle(env, inner)
    None => raise EvalError::Caused("no-codec", "ssh-key")
  }
}

///|
fn pkcs8_key_bytes(
  env : Env,
  bytes : Array[Int],
) -> Array[Int]? raise EvalError {
  match block_items(decode_der(env, binary_cell(bytes))) {
    Some(outer) =>
      if outer.length() >= 2 && word_named(outer[0], "sequence") {
        pkcs8_octet(outer[1])
      } else {
        None
      }
    None => None
  }
}

///|
fn pkcs8_octet(body : @value.Cell) -> Array[Int]? {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 6 &&
        word_named(items[2], "sequence") &&
        word_named(items[4], "octet_string") &&
        rsa_encryption_id(items[3]) {
        binary_of(items[5])
      } else {
        None
      }
    None => None
  }
}

///|
fn rsa_encryption_id(body : @value.Cell) -> Bool {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 2 && word_named(items[0], "object_identifier") {
        match binary_of(items[1]) {
          Some(oid) =>
            oid.length() == 9 &&
            oid[0] == 0x2A &&
            oid[1] == 0x86 &&
            oid[2] == 0x48 &&
            oid[3] == 0x86 &&
            oid[4] == 0xF7 &&
            oid[5] == 0x0D &&
            oid[6] == 0x01 &&
            oid[7] == 0x01 &&
            oid[8] == 0x01
          None => false
        }
      } else {
        false
      }
    None => false
  }
}

///|
/// PKCS#1 `RSA PRIVATE KEY`: version, modulus, exponent, then `d`, `p`, and `q`.
fn rsa_private_handle(
  env : Env,
  bytes : Array[Int],
) -> @value.Cell raise EvalError {
  let numbers = match block_items(decode_der(env, binary_cell(bytes))) {
    Some(outer) =>
      if outer.length() >= 2 && word_named(outer[0], "sequence") {
        private_numbers(outer[1])
      } else {
        None
      }
    None => None
  }
  match numbers {
    Some(parts) =>
      match
        @value.RsaKey::from_private(parts.0, parts.1, parts.2, parts.3, parts.4) {
        Some(key) => @value.Handle(key)
        None => raise EvalError::Caused("no-codec", "ssh-key")
      }
    None => raise EvalError::Caused("no-codec", "ssh-key")
  }
}

///|
fn private_numbers(
  body : @value.Cell,
) -> (Array[Int], Array[Int], Array[Int], Array[Int], Array[Int])? {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 12 {
        match integer_bytes(items, 3) {
          None => None
          Some(n) =>
            match integer_bytes(items, 5) {
              None => None
              Some(e) =>
                match integer_bytes(items, 7) {
                  None => None
                  Some(d) =>
                    match integer_bytes(items, 9) {
                      None => None
                      Some(p) =>
                        match integer_bytes(items, 11) {
                          None => None
                          Some(q) => Some((n, e, d, p, q))
                        }
                    }
                }
            }
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn integer_bytes(items : Array[@value.Cell], slot : Int) -> Array[Int]? {
  if slot < 1 || slot >= items.length() {
    None
  } else if word_named(items[slot - 1], "integer") {
    binary_of(items[slot])
  } else {
    None
  }
}

///|
/// Three SSH strings: the kind, the exponent, then the modulus.
fn ssh_parts(bytes : Array[Int]) -> (Array[Int], Array[Int], Array[Int])? {
  match ssh_chunk(bytes, 0) {
    None => None
    Some(kind) =>
      match ssh_chunk(bytes, kind.1) {
        None => None
        Some(exponent) =>
          match ssh_chunk(bytes, exponent.1) {
            None => None
            Some(modulus) => Some((kind.0, exponent.0, modulus.0))
          }
      }
  }
}

///|
fn ssh_chunk(bytes : Array[Int], at : Int) -> (Array[Int], Int)? {
  if at + 4 > bytes.length() {
    None
  } else {
    let size = (bytes[at].to_int64() << 24) +
      (bytes[at + 1].to_int64() << 16) +
      (bytes[at + 2].to_int64() << 8) +
      bytes[at + 3].to_int64()
    let next = at + 4
    if size < 0 || size > 1000000 || next + size.to_int() > bytes.length() {
      None
    } else {
      let out : Array[Int] = []
      let mut index = 0
      let count = size.to_int()
      while index < count {
        out.push(bytes[next + index])
        index = index + 1
      }
      Some((out, next + count))
    }
  }
}

///|
fn has_prefix(text : String, prefix : String) -> Bool {
  if text.length() < prefix.length() {
    false
  } else {
    let mut index = 0
    let mut same = true
    while same && index < prefix.length() {
      if text[index] != prefix[index] {
        same = false
      }
      index = index + 1
    }
    same
  }
}
