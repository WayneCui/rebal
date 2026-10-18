///|
/// `rsa-init` builds an RSA handle. `/private` also stores `d`, `p`, and `q`.
/// A modulus or exponent that fails the public-key check becomes `none`.
fn perform_rsa_init(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let modulus = payload_bytes(args[0], "rsa-init")
  let exponent = payload_bytes(args[1], "rsa-init")
  if rsa_init_private(env, active) {
    let secret = payload_bytes(args[2], "rsa-init")
    let prime = payload_bytes(args[3], "rsa-init")
    let other = payload_bytes(args[4], "rsa-init")
    match @value.RsaKey::from_private(modulus, exponent, secret, prime, other) {
      Some(key) => @value.Handle(@value.HandleValue::Rsa(key))
      None => @value.None
    }
  } else {
    match @value.RsaKey::new(modulus, exponent) {
      Some(key) => @value.Handle(@value.HandleValue::Rsa(key))
      None => @value.None
    }
  }
}

///|
fn rsa_init_extra(env : Env, active : Array[Int]) -> Int {
  if named(env, active, "private") {
    3
  } else {
    0
  }
}

///|
extern "C" fn c_random_byte() -> Int = "rebal_random_byte"

///|
/// `rsa/sign` and `rsa/verify` use PKCS#1 v1.5. The digest defaults to SHA-256.
/// `/hash` selects md5, sha1, sha256, sha384, or sha512.
/// `rsa/encrypt` and `rsa/decrypt` use PKCS#1 v1.5 type 2 padding.
/// `/oaep` or `/pss` selects PKCS#1 v2.1: OAEP for encrypt, PSS for sign.
/// Signing or decrypting without a private exponent returns `none`.
fn perform_rsa(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  match rsa_call(env, args, active) {
    None => @value.None
    Some(call) => {
      let key = rsa_key(args[0])
      let data = payload_bytes(args[1], "rsa")
      if call.action == "sign" {
        let coded = if call.v21 {
          rsa_pss_sign(key, data, call.digest)
        } else {
          rsa_sign(key, data, call.digest)
        }
        match coded {
          Some(bytes) => binary_cell(bytes)
          None => @value.None
        }
      } else if call.action == "verify" {
        match call.signature {
          None => raise EvalError::Cannot("rsa")
          Some(signature) => {
            let verdict = if call.v21 {
              rsa_pss_verify(key, data, signature, call.digest)
            } else {
              rsa_verify(key, data, signature, call.digest)
            }
            match verdict {
              None => @value.None
              Some(flag) => @value.Logic(flag)
            }
          }
        }
      } else if call.action == "encrypt" {
        let coded = if call.v21 {
          rsa_oaep_encrypt(key, data, call.digest)
        } else {
          rsa_encrypt(key, data)
        }
        match coded {
          Some(bytes) => binary_cell(bytes)
          None => @value.None
        }
      } else {
        let coded = if call.v21 {
          rsa_oaep_decrypt(key, data, call.digest)
        } else {
          rsa_decrypt(key, data)
        }
        match coded {
          Some(bytes) => binary_cell(bytes)
          None => @value.None
        }
      }
    }
  }
}

///|
priv struct RsaCall {
  action : String
  digest : String
  signature : Array[Int]?
  v21 : Bool
}

///|
fn rsa_extra(env : Env, active : Array[Int]) -> Int {
  let mut extra = 0
  if named(env, active, "verify") {
    extra = extra + 1
  }
  if named(env, active, "hash") {
    extra = extra + 1
  }
  extra
}

///|
fn rsa_call(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> RsaCall? raise EvalError {
  let mut action = ""
  let mut digest = "sha256"
  let mut signature : Array[Int]? = None
  let mut known = true
  let mut v21 = false
  let mut cursor = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "sign" ||
      name == "encrypt" ||
      name == "decrypt" ||
      name == "verify" {
      if action != "" {
        raise EvalError::Cannot("rsa")
      }
      action = name
      if name == "verify" {
        signature = Some(payload_bytes(args[cursor], "rsa"))
        cursor = cursor + 1
      }
    } else if name == "hash" {
      match hash_name(env, args[cursor]) {
        Some(word) => digest = word
        None => known = false
      }
      cursor = cursor + 1
    } else if name == "oaep" || name == "pss" {
      v21 = true
    } else {
      raise EvalError::Cannot("rsa")
    }
  }
  if action == "" {
    raise EvalError::Cannot("rsa")
  } else if known {
    Some({ action, digest, signature, v21, })
  } else {
    None
  }
}

///|
fn hash_name(env : Env, value : @value.Cell) -> String? {
  match value {
    @value.Sym(_, lexeme) => {
      let name = env.symbols.canon(lexeme.sym())
      if name == "md5" ||
        name == "sha1" ||
        name == "sha256" ||
        name == "sha384" ||
        name == "sha512" {
        Some(name)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn rsa_key(value : @value.Cell) -> @value.RsaKey raise EvalError {
  match value {
    @value.Handle(handle) =>
      match handle {
        @value.Rsa(key) =>
          if key.released() {
            raise EvalError::Cannot("rsa")
          } else {
            key
          }
        _ => raise EvalError::Cannot("rsa")
      }
    _ => raise EvalError::Cannot("rsa")
  }
}

///|
fn rsa_sign(
  key : @value.RsaKey,
  data : Array[Int],
  digest : String,
) -> Array[Int]? {
  if key.d.length() == 0 {
    None
  } else {
    let width = unsigned_width(key.n)
    match emsa_pkcs1(digest_info(digest, data), width) {
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
fn rsa_verify(
  key : @value.RsaKey,
  data : Array[Int],
  signature : Array[Int],
  digest : String,
) -> Bool? {
  let width = unsigned_width(key.n)
  match emsa_pkcs1(digest_info(digest, data), width) {
    None => None
    Some(encoded) =>
      if signature.length() != width {
        Some(false)
      } else {
        Some(
          same_bytes(
            @num.Nat::mod_exp(
              @num.Nat::from_bytes(signature),
              @num.Nat::from_bytes(key.e),
              @num.Nat::from_bytes(key.n),
            ).be_bytes(width),
            encoded,
          ),
        )
      }
  }
}

///|
fn digest_info(digest : String, data : Array[Int]) -> Array[Int] {
  if digest == "md5" {
    [
      0x30, 0x20, 0x30, 0x0C, 0x06, 0x08, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x02,
      0x05, 0x05, 0x00, 0x04, 0x10,
    ] +
    md5(data)
  } else if digest == "sha1" {
    [
      0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2B, 0x0E, 0x03, 0x02, 0x1A, 0x05, 0x00,
      0x04, 0x14,
    ] +
    sha1(data)
  } else if digest == "sha384" {
    [
      0x30, 0x41, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04,
      0x02, 0x02, 0x05, 0x00, 0x04, 0x30,
    ] +
    sha384(data)
  } else if digest == "sha512" {
    [
      0x30, 0x51, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04,
      0x02, 0x03, 0x05, 0x00, 0x04, 0x40,
    ] +
    sha512(data)
  } else {
    [
      0x30, 0x31, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04,
      0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
    ] +
    sha256(data)
  }
}

///|
fn emsa_pkcs1(info : Array[Int], width : Int) -> Array[Int]? {
  let pad = width - info.length() - 3
  if pad < 8 {
    None
  } else {
    let encoded : Array[Int] = [0x00, 0x01]
    let mut index = 0
    while index < pad {
      encoded.push(0xFF)
      index = index + 1
    }
    encoded.push(0x00)
    for byte in info {
      encoded.push(byte)
    }
    Some(encoded)
  }
}

///|
fn rsa_encrypt(key : @value.RsaKey, data : Array[Int]) -> Array[Int]? {
  let width = unsigned_width(key.n)
  match pkcs1_type2(data, width) {
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
fn rsa_decrypt(key : @value.RsaKey, cipher : Array[Int]) -> Array[Int]? {
  let width = unsigned_width(key.n)
  if key.d.length() == 0 || cipher.length() != width {
    None
  } else {
    unpad_type2(
      @num.Nat::mod_exp(
        @num.Nat::from_bytes(cipher),
        @num.Nat::from_bytes(key.d),
        @num.Nat::from_bytes(key.n),
      ).be_bytes(width),
    )
  }
}

///|
fn pkcs1_type2(message : Array[Int], width : Int) -> Array[Int]? {
  let pad = width - message.length() - 3
  if pad < 8 {
    None
  } else {
    let encoded : Array[Int] = [0x00, 0x02]
    let mut index = 0
    let mut ok = true
    while index < pad && ok {
      match nonzero_byte() {
        Some(byte) => encoded.push(byte)
        None => ok = false
      }
      index = index + 1
    }
    if ok {
      encoded.push(0x00)
      for byte in message {
        encoded.push(byte)
      }
      Some(encoded)
    } else {
      None
    }
  }
}

///|
fn unpad_type2(encoded : Array[Int]) -> Array[Int]? {
  if encoded.length() < 11 || encoded[0] != 0 || encoded[1] != 2 {
    None
  } else {
    let mut index = 2
    let mut filled = 0
    while index < encoded.length() && encoded[index] != 0 {
      filled = filled + 1
      index = index + 1
    }
    if index >= encoded.length() || filled < 8 {
      None
    } else {
      let message : Array[Int] = []
      let mut cursor = index + 1
      while cursor < encoded.length() {
        message.push(encoded[cursor])
        cursor = cursor + 1
      }
      Some(message)
    }
  }
}

///|
fn nonzero_byte() -> Int? {
  let mut spins = 0
  while spins < 64 {
    let byte = c_random_byte()
    if byte != 0 {
      return Some(byte)
    }
    spins = spins + 1
  }
  None
}

///|
fn unsigned_width(bytes : Array[Int]) -> Int {
  let mut index = 0
  while index < bytes.length() && bytes[index] == 0 {
    index = index + 1
  }
  bytes.length() - index
}

///|
fn rsa_init_private(env : Env, active : Array[Int]) -> Bool raise EvalError {
  let mut secret = false
  for sym in active {
    if env.symbols.canon(sym) == "private" {
      secret = true
    } else {
      raise EvalError::Cannot("rsa-init")
    }
  }
  secret
}
