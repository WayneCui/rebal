///|
/// One open `crypt://` port. Bytes wait until a full AES block, then the
/// ciphertext (or plaintext) sits in `output` until `read`.
priv struct CryptSlot {
  mut live : Bool
  mut encrypting : Bool
  mut key_ready : Bool
  mut key_len : Int
  mut cbc : Bool
  mut iv_ready : Bool
  mut iv : Array[Int]
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
    "update" => crypt_update(port)
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
/// AES ECB and CBC. `#decrypt` starts in decrypt. CBC needs an init vector.
fn crypt_open(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  match port {
    @value.Port(value) =>
      if value.is_open() {
        raise EvalError::Cannot("open")
      } else {
        let (algorithm, direction) = crypt_choice(env, value)
        match cipher_kind(algorithm) {
          Some(kind) => {
            let handle = crypt_alloc(direction == "decrypt", kind.0, kind.1)
            value.set_handle(handle)
            errdefer (if !value.is_open() {
              crypt_drop(handle)
              value.set_handle(-1)
            })
            crypt_take_spec(env, value)
            value.set_opened(true)
            port
          }
          None => raise EvalError::Cannot("open")
        }
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
        "algorithm" => crypt_set_algorithm(slot, value)
        "init-vector" | "iv" => crypt_set_iv(slot, value)
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
  if key.length() != slot.key_len {
    raise EvalError::Cannot("modify")
  }
  slot.rounds = aes_rounds(key)
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
fn crypt_set_algorithm(
  slot : CryptSlot,
  value : @value.Cell,
) -> Unit raise EvalError {
  match value {
    @value.Sym(_, lexeme) =>
      match cipher_kind(lexeme.spelling().to_lower()) {
        Some(kind) => {
          slot.key_len = kind.0
          slot.cbc = kind.1
          slot.key_ready = false
          slot.rounds = []
          slot.pending = []
        }
        None => raise EvalError::Cannot("modify")
      }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
/// Key length, then whether the mode chains blocks with the init vector.
fn cipher_kind(name : String) -> (Int, Bool)? {
  if name == "aes-128-ecb" {
    Some((16, false))
  } else if name == "aes-192-ecb" {
    Some((24, false))
  } else if name == "aes-256-ecb" {
    Some((32, false))
  } else if name == "aes-128-cbc" {
    Some((16, true))
  } else if name == "aes-192-cbc" {
    Some((24, true))
  } else if name == "aes-256-cbc" {
    Some((32, true))
  } else {
    None
  }
}

///|
/// ECB ignores the vector. CBC keeps a 16-byte vector and updates it per block.
fn crypt_set_iv(slot : CryptSlot, value : @value.Cell) -> Unit raise EvalError {
  match value {
    @value.None =>
      if slot.cbc {
        slot.iv = []
        slot.iv_ready = false
      }
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      if slot.cbc {
        let bytes = bytes_from(series, index)
        if bytes.length() != 16 {
          raise EvalError::Cannot("modify")
        }
        slot.iv = bytes
        slot.iv_ready = true
      }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
/// Pads a short block with zeros, then encrypts or decrypts it.
fn crypt_update(port : @value.Cell) -> @value.Cell raise EvalError {
  let slot = crypt_slot(port)
  if slot.pending.length() > 0 {
    if !slot.key_ready || (slot.cbc && !slot.iv_ready) {
      raise EvalError::Cannot("update")
    }
    while slot.pending.length() < 16 {
      slot.pending.push(0)
    }
    let block = crypt_block(slot)
    for out in block {
      slot.output.push(out)
    }
    slot.pending = []
  }
  port
}

///|
/// `take` on a crypt port pads, then reads. Other values stay on series `take`.
fn perform_take(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Port(port) if port.name == "crypt" => {
      let _ = crypt_update(value)
      crypt_read(value)
    }
    _ => from_action(@action.take(value))
  }
}

///|
fn perform_update(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Port(port) if port.name == "crypt" => crypt_update(value)
    _ => raise EvalError::Cannot("update")
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
      let block = crypt_block(slot)
      for out in block {
        slot.output.push(out)
      }
      slot.pending = []
    }
  }
}

///|
fn crypt_block(slot : CryptSlot) -> Array[Int] raise EvalError {
  if !slot.cbc {
    if slot.encrypting {
      aes_encrypt(slot.rounds, slot.pending)
    } else {
      aes_decrypt(slot.rounds, slot.pending)
    }
  } else if !slot.iv_ready {
    raise EvalError::Cannot("write")
  } else if slot.encrypting {
    let mixed = chain_xor(slot.pending, slot.iv)
    let out = aes_encrypt(slot.rounds, mixed)
    slot.iv = copy_block(out)
    out
  } else {
    let plain = aes_decrypt(slot.rounds, slot.pending)
    let out = chain_xor(plain, slot.iv)
    slot.iv = copy_block(slot.pending)
    out
  }
}

///|
fn crypt_alloc(decrypting : Bool, key_len : Int, cbc : Bool) -> Int {
  let mut index = 0
  let mut found = -1
  while index < crypts.slots.length() && found < 0 {
    if !crypts.slots[index].live {
      found = index
    }
    index = index + 1
  }
  if found >= 0 {
    crypt_reset(crypts.slots[found], decrypting, key_len, cbc)
    found
  } else {
    let slot = crypt_fresh(decrypting, key_len, cbc)
    crypts.slots.push(slot)
    crypts.slots.length() - 1
  }
}

///|
fn crypt_fresh(decrypting : Bool, key_len : Int, cbc : Bool) -> CryptSlot {
  {
    live: true,
    encrypting: !decrypting,
    key_ready: false,
    key_len,
    cbc,
    iv_ready: false,
    iv: [],
    rounds: [],
    pending: [],
    output: [],
  }
}

///|
fn crypt_reset(
  slot : CryptSlot,
  decrypting : Bool,
  key_len : Int,
  cbc : Bool,
) -> Unit {
  slot.live = true
  slot.encrypting = !decrypting
  slot.key_ready = false
  slot.key_len = key_len
  slot.cbc = cbc
  slot.iv_ready = false
  slot.iv = []
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
/// Copies the crypt fields of a `make port!` object onto the port spec.
fn note_crypt_spec(
  env : Env,
  from : @value.Frame,
  port : @value.Cell,
) -> Unit raise EvalError {
  match port {
    @value.Port(value) => {
      copy_spec_field(env, from, value.spec, "algorithm")
      copy_spec_field(env, from, value.spec, "direction")
      copy_spec_field(env, from, value.spec, "key")
      copy_spec_field(env, from, value.spec, "init-vector")
      copy_spec_field(env, from, value.spec, "iv")
    }
    _ => ()
  }
}

///|
fn copy_spec_field(
  env : Env,
  from : @value.Frame,
  into : @value.Frame,
  spelling : String,
) -> Unit raise EvalError {
  match frame_field(env, from, spelling) {
    Some(cell) => put_field(env, into, spelling, cell)
    None => ()
  }
}

///|
/// URL host wins over `algorithm`. A `#decrypt` fragment wins over `direction`.
fn crypt_choice(
  env : Env,
  port : @value.PortValue,
) -> (String, String) raise EvalError {
  let url = match frame_field(env, port.spec, "ref") {
    Some(@value.Seq(series, index)) if series.datatype() == @value.Url =>
      Some(crypt_target(text_from(series, index)))
    _ => None
  }
  let algorithm = match url {
    Some((host, _)) => host
    None =>
      match spec_word(env, port.spec, "algorithm") {
        Some(name) => name
        None => raise EvalError::Cannot("open")
      }
  }
  let direction = match url {
    Some((_, Some(fragment))) => fragment
    _ => spec_direction(env, port.spec)
  }
  (algorithm, direction)
}

///|
fn spec_direction(env : Env, frame : @value.Frame) -> String raise EvalError {
  match spec_word(env, frame, "direction") {
    Some(name) =>
      if name == "encrypt" || name == "decrypt" {
        name
      } else {
        raise EvalError::Cannot("open")
      }
    None => "encrypt"
  }
}

///|
fn spec_word(env : Env, frame : @value.Frame, spelling : String) -> String? {
  match frame_field(env, frame, spelling) {
    Some(@value.Sym(_, lexeme)) => Some(lexeme.spelling().to_lower())
    _ => None
  }
}

///|
fn crypt_take_spec(env : Env, port : @value.PortValue) -> Unit raise EvalError {
  let slot = crypt_at(port.handle())
  match frame_field(env, port.spec, "key") {
    Some(cell) => crypt_use_key(slot, cell)
    None => ()
  }
  match frame_field(env, port.spec, "init-vector") {
    Some(cell) => crypt_use_iv(slot, cell)
    None =>
      match frame_field(env, port.spec, "iv") {
        Some(cell) => crypt_use_iv(slot, cell)
        None => ()
      }
  }
}

///|
fn crypt_use_key(slot : CryptSlot, value : @value.Cell) -> Unit raise EvalError {
  match value {
    @value.None => ()
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let key = bytes_from(series, index)
      if key.length() != slot.key_len {
        raise EvalError::Cannot("open")
      }
      slot.rounds = aes_rounds(key)
      slot.key_ready = true
      slot.pending = []
    }
    _ => raise EvalError::Cannot("open")
  }
}

///|
fn crypt_use_iv(slot : CryptSlot, value : @value.Cell) -> Unit raise EvalError {
  match value {
    @value.None => ()
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      if slot.cbc {
        let bytes = bytes_from(series, index)
        if bytes.length() != 16 {
          raise EvalError::Cannot("open")
        }
        slot.iv = bytes
        slot.iv_ready = true
      }
    _ => raise EvalError::Cannot("open")
  }
}

///|
/// Host is the algorithm. The fragment, when present, is `encrypt` or `decrypt`.
fn crypt_target(text : String) -> (String, String?) raise EvalError {
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
    (host, None)
  } else {
    let fragment = text[end + 1:text.length()].to_owned().to_lower()
    if fragment == "encrypt" || fragment == "decrypt" {
      (host, Some(fragment))
    } else {
      raise EvalError::Cannot("open")
    }
  }
}
