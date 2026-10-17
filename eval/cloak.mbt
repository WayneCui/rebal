///|
/// Scrambles a binary in place. Without `/with`, the key is repeated to 20 bytes and hashed with SHA-1.
fn perform_encloak(
  env : Env,
  data : @value.Cell,
  key : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  cloak(env, data, key, false, active, "encloak")
}

///|
/// Restores a binary scrambled by `encloak`. The same key and `/with` are required.
fn perform_decloak(
  env : Env,
  data : @value.Cell,
  key : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  cloak(env, data, key, true, active, "decloak")
}

///|
fn cloak(
  env : Env,
  data : @value.Cell,
  key : @value.Cell,
  decode : Bool,
  active : Array[Int],
  action : String,
) -> @value.Cell raise EvalError {
  let raw_key = cloak_raw(env, active, action)
  match data {
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let bytes = bytes_from(series, index)
      let secret = cloak_key(key, action, raw_key)
      let changed = if decode {
        decloak_bytes(bytes, secret)
      } else {
        encloak_bytes(bytes, secret)
      }
      let mut at = if index < 0 { 0 } else { index }
      for byte in changed {
        series.set_byte(at, byte.to_byte()) |> ignore
        at = at + 1
      }
      data
    }
    _ => raise EvalError::Cannot(action)
  }
}

///|
fn cloak_raw(
  env : Env,
  active : Array[Int],
  action : String,
) -> Bool raise EvalError {
  let mut raw = false
  for sym in active {
    if env.symbols.canon(sym) == "with" {
      raw = true
    } else {
      raise EvalError::Cannot(action)
    }
  }
  raw
}

///|
fn cloak_key(
  key : @value.Cell,
  action : String,
  raw_key : Bool,
) -> Array[Int] raise EvalError {
  let raw = payload_bytes(key, action)
  if raw.length() == 0 {
    raise EvalError::Cannot(action)
  }
  if raw_key {
    raw
  } else {
    let src : Array[Int] = []
    for i in 0..<20 {
      src.push(raw[i % raw.length()])
    }
    sha1(src)
  }
}

///|
fn encloak_bytes(data : Array[Int], key : Array[Int]) -> Array[Int] {
  if data.length() == 0 {
    return data
  }
  let mut mixed = 0xA5
  for i in 1..<data.length() {
    mixed = (mixed + data[i]) & 0xFF
  }
  data[0] = data[0] ^ mixed
  for i in 1..<data.length() {
    data[i] = data[i] ^ data[i - 1] ^ key[i % key.length()]
  }
  data
}

///|
fn decloak_bytes(data : Array[Int], key : Array[Int]) -> Array[Int] {
  if data.length() == 0 {
    return data
  }
  let mut i = data.length() - 1
  while i > 0 {
    data[i] = data[i] ^ data[i - 1] ^ key[i % key.length()]
    i = i - 1
  }
  let mut mixed = 0xA5
  for j in 1..<data.length() {
    mixed = (mixed + data[j]) & 0xFF
  }
  data[0] = data[0] ^ mixed
  data
}
