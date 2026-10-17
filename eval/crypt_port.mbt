///|
/// One open `crypt://` port. Bytes wait until a full AES block, then the
/// ciphertext (or plaintext) sits in `output` until `read`.
priv struct CryptSlot {
  mut live : Bool
  mut encrypting : Bool
  mut key_ready : Bool
  mut rounds : Array[Int]
  mut pending : Array[Int]
  mut output : Array[Int]
}

///|
priv struct CryptTable {
  slots : Array[CryptSlot]
}

///|
let crypts : CryptTable = { slots: [], }

///|
fn crypt_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  match action {
    "open" => crypt_open(env, port)
    "close" => crypt_close(port)
    "read" => crypt_read(port)
    "write" =>
      match extra {
        Some(value) => crypt_write(port, value)
        None => raise EvalError::Cannot("write")
      }
    _ => {
      let _ = (env, extra)
      raise EvalError::Cannot("port")
    }
  }
}

///|
/// `crypt://aes-128-ecb` encrypts. A `#decrypt` fragment starts in decrypt.
fn crypt_open(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  match port {
    @value.Port(value) =>
      if value.is_open() {
        raise EvalError::Cannot("open")
      } else {
        let (algorithm, direction) = crypt_target(port_url(env, value))
        if algorithm != "aes-128-ecb" {
          raise EvalError::Cannot("open")
        }
        let handle = crypt_alloc(direction == "decrypt")
        value.set_handle(handle)
        value.set_opened(true)
        port
      }
    _ => raise EvalError::Cannot("open")
  }
}

///|
fn crypt_close(port : @value.Cell) -> @value.Cell raise EvalError {
  match port {
    @value.Port(value) => {
      crypt_drop(value.handle())
      value.set_handle(-1)
      value.set_opened(false)
      port
    }
    _ => raise EvalError::Cannot("close")
  }
}

///|
fn crypt_read(port : @value.Cell) -> @value.Cell raise EvalError {
  let slot = crypt_slot(port)
  if slot.output.length() == 0 {
    @value.None
  } else {
    let cell = binary_cell(slot.output)
    slot.output = []
    cell
  }
}

///|
fn crypt_write(
  port : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let bytes = match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => raise EvalError::Cannot("write")
  }
  crypt_absorb(crypt_slot(port), bytes)
  port
}

///|
/// Sets `key`, `direction`, `algorithm`, or `init-vector` on an open crypt port.
fn perform_modify(
  env : Env,
  target : @value.Cell,
  field : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  match target {
    @value.Port(port) =>
      if port.name != "crypt" || !port.is_open() {
        raise EvalError::Cannot("port")
      } else {
        crypt_modify(env, port, field, value)
        target
      }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
fn crypt_modify(
  env : Env,
  port : @value.PortValue,
  field : @value.Cell,
  value : @value.Cell,
) -> Unit raise EvalError {
  let slot = crypt_at(port.handle())
  match field {
    @value.Sym(_, lexeme) =>
      match lexeme.spelling().to_lower() {
        "key" => crypt_set_key(slot, value)
        "direction" => crypt_set_direction(slot, value)
        "algorithm" => crypt_set_algorithm(value)
        "init-vector" | "iv" => crypt_set_iv(value)
        _ => {
          let _ = env
          raise EvalError::Cannot("modify")
        }
      }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
fn crypt_set_key(slot : CryptSlot, value : @value.Cell) -> Unit raise EvalError {
  let key = match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => raise EvalError::Cannot("modify")
  }
  slot.rounds = aes128_rounds(key)
  slot.key_ready = true
  slot.pending = []
}

///|
fn crypt_set_direction(
  slot : CryptSlot,
  value : @value.Cell,
) -> Unit raise EvalError {
  slot.encrypting = match value {
    @value.Sym(_, lexeme) =>
      match lexeme.spelling().to_lower() {
        "encrypt" => true
        "decrypt" => false
        _ => raise EvalError::Cannot("modify")
      }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
fn crypt_set_algorithm(value : @value.Cell) -> Unit raise EvalError {
  match value {
    @value.Sym(_, lexeme) =>
      if lexeme.spelling().to_lower() != "aes-128-ecb" {
        raise EvalError::Cannot("modify")
      }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
/// ECB ignores the vector. `none` is the value the FIPS tests pass.
fn crypt_set_iv(value : @value.Cell) -> Unit raise EvalError {
  match value {
    @value.None => ()
    @value.Seq(series, _) if series.datatype() == @value.Binary => ()
    _ => raise EvalError::Cannot("modify")
  }
}

///|
fn crypt_absorb(slot : CryptSlot, bytes : Array[Int]) -> Unit raise EvalError {
  if !slot.key_ready {
    raise EvalError::Cannot("write")
  }
  for byte in bytes {
    slot.pending.push(byte)
    if slot.pending.length() == 16 {
      let block = if slot.encrypting {
        aes128_encrypt(slot.rounds, slot.pending)
      } else {
        aes128_decrypt(slot.rounds, slot.pending)
      }
      for out in block {
        slot.output.push(out)
      }
      slot.pending = []
    }
  }
}

///|
fn crypt_alloc(decrypting : Bool) -> Int {
  let mut index = 0
  let mut found = -1
  while index < crypts.slots.length() && found < 0 {
    if !crypts.slots[index].live {
      found = index
    }
    index = index + 1
  }
  if found >= 0 {
    crypt_reset(crypts.slots[found], decrypting)
    found
  } else {
    let slot = crypt_fresh(decrypting)
    crypts.slots.push(slot)
    crypts.slots.length() - 1
  }
}

///|
fn crypt_fresh(decrypting : Bool) -> CryptSlot {
  {
    live: true,
    encrypting: !decrypting,
    key_ready: false,
    rounds: [],
    pending: [],
    output: [],
  }
}

///|
fn crypt_reset(slot : CryptSlot, decrypting : Bool) -> Unit {
  slot.live = true
  slot.encrypting = !decrypting
  slot.key_ready = false
  slot.rounds = []
  slot.pending = []
  slot.output = []
}

///|
fn crypt_drop(handle : Int) -> Unit {
  if handle >= 0 && handle < crypts.slots.length() {
    crypts.slots[handle].live = false
  }
}

///|
fn crypt_slot(port : @value.Cell) -> CryptSlot raise EvalError {
  match port {
    @value.Port(value) =>
      if value.is_open() {
        crypt_at(value.handle())
      } else {
        raise EvalError::Cannot("port")
      }
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn crypt_at(handle : Int) -> CryptSlot raise EvalError {
  if handle < 0 || handle >= crypts.slots.length() {
    raise EvalError::Cannot("port")
  }
  let slot = crypts.slots[handle]
  if slot.live {
    slot
  } else {
    raise EvalError::Cannot("port")
  }
}

///|
fn port_url(env : Env, port : @value.PortValue) -> String raise EvalError {
  match frame_field(env, port.spec, "ref") {
    Some(@value.Seq(series, index)) if series.datatype() == @value.Url =>
      text_from(series, index)
    _ => raise EvalError::Cannot("open")
  }
}

///|
/// Host is the algorithm. The fragment, when present, is `encrypt` or `decrypt`.
fn crypt_target(text : String) -> (String, String) raise EvalError {
  let mut colon = -1
  let mut index = 0
  while index < text.length() && colon < 0 {
    if text[index].to_int() == 58 {
      colon = index
    }
    index = index + 1
  }
  if colon < 0 {
    raise EvalError::Cannot("open")
  }
  let mut start = colon + 1
  while start < text.length() && text[start].to_int() == 47 {
    start = start + 1
  }
  let mut end = text.length()
  let mut cursor = start
  while cursor < text.length() && end == text.length() {
    if text[cursor].to_int() == 35 {
      end = cursor
    }
    cursor = cursor + 1
  }
  let host = text[start:end].to_owned().to_lower()
  if host.length() == 0 {
    raise EvalError::Cannot("open")
  }
  if end == text.length() {
    (host, "encrypt")
  } else {
    let fragment = text[end + 1:text.length()].to_owned().to_lower()
    if fragment == "encrypt" || fragment == "decrypt" {
      (host, fragment)
    } else {
      raise EvalError::Cannot("open")
    }
  }
}
