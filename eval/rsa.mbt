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
/// `rsa/sign` and `rsa/verify` use PKCS#1 v1.5 and SHA-256.
/// `rsa/encrypt` and `rsa/decrypt` use PKCS#1 v1.5 type 2 padding.
/// Signing or decrypting without a private exponent returns `none`.
fn perform_rsa(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let key = rsa_key(args[0])
  let data = payload_bytes(args[1], "rsa")
  let action = rsa_action(env, active)
  if action == "sign" {
    match rsa_sign_sha256(key, data) {
      Some(bytes) => binary_cell(bytes)
      None => @value.None
    }
  } else if action == "verify" {
    let signature = payload_bytes(args[2], "rsa")
    @value.Logic(rsa_verify_sha256(key, data, signature))
  } else if action == "encrypt" {
    match rsa_encrypt(key, data) {
      Some(bytes) => binary_cell(bytes)
      None => @value.None
    }
  } else {
    match rsa_decrypt(key, data) {
      Some(bytes) => binary_cell(bytes)
      None => @value.None
    }
  }
}

///|
fn rsa_extra(env : Env, active : Array[Int]) -> Int {
  if named(env, active, "verify") {
    1
  } else {
    0
  }
}

///|
fn rsa_action(env : Env, active : Array[Int]) -> String raise EvalError {
  let mut action = ""
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "sign" ||
      name == "verify" ||
      name == "encrypt" ||
      name == "decrypt" {
      if action != "" {
        raise EvalError::Cannot("rsa")
      }
      action = name
    } else {
      raise EvalError::Cannot("rsa")
    }
  }
  if action == "" {
    raise EvalError::Cannot("rsa")
  }
  action
}

///|
fn rsa_key(value : @value.Cell) -> @value.RsaKey raise EvalError {
  match value {
    @value.Handle(@value.Rsa(key)) => key
    _ => raise EvalError::Cannot("rsa")
  }
}

///|
fn rsa_sign_sha256(key : @value.RsaKey, data : Array[Int]) -> Array[Int]? {
  if key.d.length() == 0 {
    None
  } else {
    let width = unsigned_width(key.n)
    match emsa_pkcs1(sha256_info(sha256(data)), width) {
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
fn rsa_verify_sha256(
  key : @value.RsaKey,
  data : Array[Int],
  signature : Array[Int],
) -> Bool {
  let width = unsigned_width(key.n)
  if signature.length() != width {
    false
  } else {
    match emsa_pkcs1(sha256_info(sha256(data)), width) {
      None => false
      Some(encoded) =>
        same_bytes(
          @num.Nat::mod_exp(
            @num.Nat::from_bytes(signature),
            @num.Nat::from_bytes(key.e),
            @num.Nat::from_bytes(key.n),
          ).be_bytes(width),
          encoded,
        )
    }
  }
}

///|
fn sha256_info(hash : Array[Int]) -> Array[Int] {
  [
    0x30, 0x31, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04,
    0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
  ] +
  hash
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
