///|
/// `ecdh/init` draws a P-256 key. `secp256r1` is the only curve so far.
/// `/public` is the uncompressed point. `/secret` is the shared x coordinate.
/// A released handle yields `none` until `/init` replaces it.
fn perform_ecdh(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut init = false
  let mut mode = ""
  let mut curve = ""
  let mut peer : Array[Int]? = None
  let mut cursor = 1
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "init" {
      init = true
      match curve_word(env, args[cursor]) {
        Some(word) => curve = word
        None => return @value.None
      }
      cursor = cursor + 1
    } else if name == "public" || name == "curve" || name == "secret" {
      if mode != "" {
        raise EvalError::Cannot("ecdh")
      }
      mode = name
      if name == "secret" {
        peer = Some(payload_bytes(args[cursor], "ecdh"))
        cursor = cursor + 1
      }
    } else {
      raise EvalError::Cannot("ecdh")
    }
  }
  let mut holder = args[0]
  if init {
    match ecdh_material(curve) {
      None => return @value.None
      Some((secret, px, py)) =>
        match holder {
          @value.None =>
            holder = @value.Handle(
              @value.HandleValue::Ecdh(
                @value.EcdhKey::fresh(curve, secret, px, py),
              ),
            )
          @value.Handle(@value.Ecdh(key)) => key.restart(curve, secret, px, py)
          _ => return @value.None
        }
    }
  }
  match holder {
    @value.Handle(@value.Ecdh(key)) =>
      if !init && key.released() {
        @value.None
      } else if mode == "public" {
        binary_cell(ecdh_point(key))
      } else if mode == "curve" {
        curve_cell(env, key.curve())
      } else if mode == "secret" {
        match peer {
          None => @value.None
          Some(value) =>
            match ecdh_shared(key, value) {
              None => @value.None
              Some(bytes) => binary_cell(bytes)
            }
        }
      } else if init {
        holder
      } else {
        raise EvalError::Cannot("ecdh")
      }
    _ => @value.None
  }
}

///|
fn ecdh_extra(env : Env, active : Array[Int]) -> Int {
  let mut extra = 0
  if named(env, active, "init") {
    extra = extra + 1
  }
  if named(env, active, "secret") {
    extra = extra + 1
  }
  extra
}

///|
fn ecdh_material(curve : String) -> (Array[Int], Array[Int], Array[Int])? {
  if curve != "secp256r1" {
    None
  } else {
    let mut tries = 0
    let mut found : (Array[Int], Array[Int], Array[Int])? = None
    while tries < 16 && found is None {
      let secret = random_span(32)
      match @num.p256_base_mul(secret) {
        Some((px, py)) => found = Some((secret, px, py))
        None => ()
      }
      tries = tries + 1
    }
    found
  }
}

///|
fn ecdh_point(key : @value.EcdhKey) -> Array[Int] {
  let out : Array[Int] = [0x04]
  for byte in key.px() {
    out.push(byte)
  }
  for byte in key.py() {
    out.push(byte)
  }
  out
}

///|
fn ecdh_shared(key : @value.EcdhKey, peer : Array[Int]) -> Array[Int]? {
  if peer.length() != 65 || peer[0] != 0x04 {
    None
  } else {
    match
      @num.p256_mul(
        key.scalar(),
        span_bytes(peer, 1, 32),
        span_bytes(peer, 33, 32),
      ) {
      Some((x, _)) => Some(x)
      None => None
    }
  }
}

///|
fn curve_word(env : Env, value : @value.Cell) -> String? {
  match value {
    @value.Sym(_, lexeme) => Some(env.symbols.canon(lexeme.sym()))
    _ => None
  }
}

///|
fn curve_cell(env : Env, spelling : String) -> @value.Cell {
  @value.Sym(
    @value.Word,
    @value.Lexeme::make(env.symbols.intern(spelling), spelling),
  )
}
