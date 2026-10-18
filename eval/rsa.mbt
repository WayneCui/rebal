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
