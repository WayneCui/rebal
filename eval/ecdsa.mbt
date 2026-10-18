///|
/// `ecdsa` signs with the private scalar. `/verify` checks an ASN.1 signature.
/// A binary public key needs `/curve`. Only `secp256r1` is accepted.
fn perform_ecdsa(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut verify = false
  let mut curve = ""
  let mut signature : Array[Int]? = None
  let mut cursor = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "sign" {
      if verify {
        raise EvalError::Cannot("ecdsa")
      }
    } else if name == "verify" {
      verify = true
      signature = Some(payload_bytes(args[cursor], "ecdsa"))
      cursor = cursor + 1
    } else if name == "curve" {
      match curve_word(env, args[cursor]) {
        Some(word) => curve = word
        None => return @value.None
      }
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("ecdsa")
    }
  }
  let hash = payload_bytes(args[1], "ecdsa")
  match ecdsa_key(args[0], curve) {
    None => @value.None
    Some(key) =>
      if verify {
        match signature {
          None => @value.None
          Some(bytes) => ecdsa_check(key, hash, bytes)
        }
      } else if key.secret.length() == 0 {
        @value.None
      } else {
        match ecdsa_signature(key, hash) {
          None => @value.None
          Some(bytes) => binary_cell(bytes)
        }
      }
  }
}

///|
fn ecdsa_extra(env : Env, active : Array[Int]) -> Int {
  let mut extra = 0
  if named(env, active, "verify") {
    extra = extra + 1
  }
  if named(env, active, "curve") {
    extra = extra + 1
  }
  extra
}

///|
priv struct EcdsaKey {
  secret : Array[Int]
  x : Array[Int]
  y : Array[Int]
}

///|
fn ecdsa_key(value : @value.Cell, curve : String) -> EcdsaKey? raise EvalError {
  match value {
    @value.Handle(@value.Ecdh(key)) =>
      if key.released() {
        raise EvalError::Cannot("ecdsa")
      } else if curve != "" && curve != key.curve() {
        None
      } else {
        Some({ secret: key.scalar(), x: key.px(), y: key.py(), })
      }
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      if curve != "secp256r1" {
        if curve == "" {
          raise EvalError::Cannot("ecdsa")
        } else {
          None
        }
      } else {
        let bytes = bytes_from(series, index)
        if bytes.length() != 65 || bytes[0] != 0x04 {
          None
        } else {
          Some({
            secret: [],
            x: span_bytes(bytes, 1, 32),
            y: span_bytes(bytes, 33, 32),
          })
        }
      }
    _ => raise EvalError::Cannot("ecdsa")
  }
}

///|
fn ecdsa_signature(key : EcdsaKey, hash : Array[Int]) -> Array[Int]? {
  let mut tries = 0
  let mut found : Array[Int]? = None
  while tries < 16 && found is None {
    match @num.p256_sign_rs(key.secret, hash, random_span(32)) {
      Some((r, s)) => found = Some(der_pair(r, s))
      None => ()
    }
    tries = tries + 1
  }
  found
}

///|
fn ecdsa_check(
  key : EcdsaKey,
  hash : Array[Int],
  signature : Array[Int],
) -> @value.Cell {
  match der_pair_read(signature) {
    None => @value.None
    Some((r, s)) =>
      if @num.p256_verify_rs(key.x, key.y, hash, r, s) {
        @value.Logic(true)
      } else {
        @value.None
      }
  }
}

///|
fn der_pair(r : Array[Int], s : Array[Int]) -> Array[Int] {
  let body = join_span(der_integer(r), der_integer(s))
  join_span([0x30, body.length()], body)
}

///|
fn der_integer(bytes : Array[Int]) -> Array[Int] {
  let mut index = 0
  while index < bytes.length() - 1 && bytes[index] == 0 {
    index = index + 1
  }
  let body : Array[Int] = []
  if index >= bytes.length() {
    body.push(0)
  } else {
    if bytes[index] >= 128 {
      body.push(0)
    }
    while index < bytes.length() {
      body.push(bytes[index])
      index = index + 1
    }
  }
  join_span([0x02, body.length()], body)
}

///|
fn der_pair_read(bytes : Array[Int]) -> (Array[Int], Array[Int])? {
  if bytes.length() < 2 || bytes[0] != 0x30 || bytes[1] >= 128 {
    None
  } else if bytes.length() != bytes[1] + 2 {
    None
  } else {
    match der_int_read(bytes, 2) {
      None => None
      Some((r, next)) =>
        match der_int_read(bytes, next) {
          None => None
          Some((s, end)) =>
            if end == bytes.length() {
              Some((r, s))
            } else {
              None
            }
        }
    }
  }
}

///|
fn der_int_read(bytes : Array[Int], at : Int) -> (Array[Int], Int)? {
  if at + 1 >= bytes.length() || bytes[at] != 0x02 || bytes[at + 1] >= 128 {
    None
  } else {
    let count = bytes[at + 1]
    let start = at + 2
    let end = start + count
    if count == 0 || end > bytes.length() || bytes[start] >= 128 {
      None
    } else {
      Some((span_bytes(bytes, start, count), end))
    }
  }
}
