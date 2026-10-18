///|
/// `dh-init` takes a generator and a prime, then draws a private exponent.
/// The prime's byte length must be from 64 to 512.
fn perform_dh_init(
  _env : Env,
  args : Array[@value.Cell],
) -> @value.Cell raise EvalError {
  let generator = payload_bytes(args[0], "dh-init")
  let prime = payload_bytes(args[1], "dh-init")
  let width = unsigned_width(prime)
  if width < 64 || width > 512 {
    @value.None
  } else {
    match dh_pair(generator, prime, width) {
      None => @value.None
      Some(key) => @value.Handle(@value.HandleValue::Dhm(key))
    }
  }
}

///|
fn dh_pair(
  generator : Array[Int],
  prime : Array[Int],
  width : Int,
) -> @value.DhKey? {
  let ceiling = minus_int(prime, 2)
  let mut tries = 0
  let mut found : @value.DhKey? = None
  while tries < 8 && found is None {
    match private_exponent(ceiling, width) {
      None => ()
      Some(secret) => {
        let public = trim_bytes(
          @num.Nat::mod_exp(
            @num.Nat::from_bytes(generator),
            @num.Nat::from_bytes(secret),
            @num.Nat::from_bytes(prime),
          ).be_bytes(width),
        )
        if mag_cmp(public, [2]) >= 0 && mag_cmp(public, ceiling) <= 0 {
          found = @value.DhKey::with_pair(
            prime,
            generator,
            trim_bytes(secret),
            public,
          )
        }
      }
    }
    tries = tries + 1
  }
  found
}

///|
fn private_exponent(ceiling : Array[Int], width : Int) -> Array[Int]? {
  let mut tries = 0
  let mut found : Array[Int]? = None
  while tries < 32 && found is None {
    let bytes = random_span(width)
    if mag_cmp(bytes, [2]) >= 0 && mag_cmp(bytes, ceiling) <= 0 {
      found = Some(bytes)
    }
    tries = tries + 1
  }
  found
}

///|
/// `dh/public` reads this side's public value. `dh/secret` combines the
/// peer's public value with this side's private exponent.
fn perform_dh(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let key = match args[0] {
    @value.Handle(@value.Dhm(key)) =>
      if key.released() {
        raise EvalError::Cannot("dh")
      } else {
        key
      }
    _ => return @value.None
  }
  let mut mode = ""
  let mut peer : Array[Int]? = None
  let mut cursor = 1
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "public" || name == "secret" {
      if mode != "" {
        raise EvalError::Cannot("dh")
      }
      mode = name
      if name == "secret" {
        peer = Some(payload_bytes(args[cursor], "dh"))
        cursor = cursor + 1
      }
    } else {
      raise EvalError::Cannot("dh")
    }
  }
  if mode == "public" {
    if key.gx.length() == 0 {
      @value.None
    } else {
      binary_cell(key.gx)
    }
  } else if mode == "secret" {
    match peer {
      None => @value.None
      Some(value) => dh_secret(key, value)
    }
  } else {
    raise EvalError::Cannot("dh")
  }
}

///|
fn dh_extra(env : Env, active : Array[Int]) -> Int {
  if named(env, active, "secret") {
    1
  } else {
    0
  }
}

///|
fn dh_secret(key : @value.DhKey, peer : Array[Int]) -> @value.Cell {
  let width = unsigned_width(key.p)
  let ceiling = minus_int(key.p, 2)
  if key.x.length() == 0 || mag_cmp(peer, [2]) < 0 || mag_cmp(peer, ceiling) > 0 {
    @value.None
  } else {
    binary_cell(
      trim_bytes(
        @num.Nat::mod_exp(
          @num.Nat::from_bytes(peer),
          @num.Nat::from_bytes(key.x),
          @num.Nat::from_bytes(key.p),
        ).be_bytes(width),
      ),
    )
  }
}

///|
fn mag_cmp(left : Array[Int], right : Array[Int]) -> Int {
  let a = trim_bytes(left)
  let b = trim_bytes(right)
  if a.length() != b.length() {
    if a.length() < b.length() {
      -1
    } else {
      1
    }
  } else {
    let mut index = 0
    let mut order = 0
    while index < a.length() && order == 0 {
      if a[index] < b[index] {
        order = -1
      } else if a[index] > b[index] {
        order = 1
      }
      index = index + 1
    }
    order
  }
}

///|
fn minus_int(bytes : Array[Int], amount : Int) -> Array[Int] {
  let out : Array[Int] = []
  for byte in bytes {
    out.push(byte)
  }
  let mut index = out.length() - 1
  let mut rest = amount
  while index >= 0 && rest > 0 {
    let value = out[index] - rest
    if value >= 0 {
      out[index] = value
      rest = 0
    } else {
      out[index] = value + 256
      rest = 1
    }
    index = index - 1
  }
  out
}

///|
fn trim_bytes(bytes : Array[Int]) -> Array[Int] {
  let mut index = 0
  while index < bytes.length() - 1 && bytes[index] == 0 {
    index = index + 1
  }
  span_bytes(bytes, index, bytes.length() - index)
}
