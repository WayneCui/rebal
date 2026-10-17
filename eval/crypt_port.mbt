///|
/// One open `crypt://` port. Bytes wait until a full AES block, then the
/// ciphertext (or plaintext) sits in `output` until `read`.
priv struct CryptSlot {
  mut live : Bool
  mut encrypting : Bool
  mut key_ready : Bool
  mut key_len : Int
  mut cbc : Bool
  mut camellia : Bool
  mut cam_enc : Array[UInt64]
  mut cam_dec : Array[UInt64]
  mut chacha : Bool
  mut chacha_key : Array[Int]
  mut chacha_nonce : Array[Int]
  mut chacha_base : UInt64
  mut chacha_counter : UInt64
  mut chacha_off : Int
  mut chacha_stream : Array[Int]
  mut poly : Bool
  mut poly_key : Array[Int]
  mut poly_iv : Array[Int]
  mut poly_aad : Array[Int]
  mut poly_cipher : Array[Int]
  mut poly_nonce : Array[Int]
  mut poly_counter : UInt64
  mut poly_off : Int
  mut poly_stream : Array[Int]
  mut poly_started : Bool
  mut poly_done : Bool
  mut ccm : Bool
  mut ccm_tag : Int
  mut ccm_aad : Int
  mut ccm_iv : Array[Int]
  mut ccm_reset : Bool
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
            let handle = crypt_alloc(
              direction == "decrypt",
              kind.0,
              kind.1,
              kind.2,
              kind.3,
              kind.4,
              kind.5,
            )
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
        "tag-length" => slot.ccm_tag = crypt_count(value)
        "aad-length" => slot.ccm_aad = crypt_count(value)
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
  install_key(slot, key)
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
  if slot.chacha {
    chacha_rewind(slot)
    slot.pending = []
  }
  if slot.poly {
    poly_reset(slot)
  }
  if slot.ccm {
    slot.ccm_reset = true
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
          slot.camellia = kind.2
          slot.chacha = kind.3
          slot.poly = kind.4
          slot.ccm = kind.5
          slot.key_ready = false
          slot.rounds = []
          slot.cam_enc = []
          slot.cam_dec = []
          chacha_blank(slot)
          poly_blank(slot)
          slot.pending = []
        }
        None => raise EvalError::Cannot("modify")
      }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
/// Key length, CBC, Camellia, ChaCha20, ChaCha20-Poly1305, then AES-CCM.
fn cipher_kind(name : String) -> (Int, Bool, Bool, Bool, Bool, Bool)? {
  if name == "aes-128-ecb" {
    Some((16, false, false, false, false, false))
  } else if name == "aes-192-ecb" {
    Some((24, false, false, false, false, false))
  } else if name == "aes-256-ecb" {
    Some((32, false, false, false, false, false))
  } else if name == "aes-128-cbc" {
    Some((16, true, false, false, false, false))
  } else if name == "aes-192-cbc" {
    Some((24, true, false, false, false, false))
  } else if name == "aes-256-cbc" {
    Some((32, true, false, false, false, false))
  } else if name == "camellia-128-ecb" {
    Some((16, false, true, false, false, false))
  } else if name == "camellia-128-cbc" {
    Some((16, true, true, false, false, false))
  } else if name == "camellia-192-ecb" {
    Some((24, false, true, false, false, false))
  } else if name == "camellia-192-cbc" {
    Some((24, true, true, false, false, false))
  } else if name == "camellia-256-ecb" {
    Some((32, false, true, false, false, false))
  } else if name == "camellia-256-cbc" {
    Some((32, true, true, false, false, false))
  } else if name == "chacha20" {
    Some((32, false, false, true, false, false))
  } else if name == "chacha20-poly1305" {
    Some((32, false, false, false, true, false))
  } else if name == "aes-128-ccm" {
    Some((16, false, false, false, false, true))
  } else if name == "aes-256-ccm" {
    Some((32, false, false, false, false, true))
  } else {
    None
  }
}

///|
/// ECB ignores the vector. CBC keeps a 16-byte vector and updates it per block.
fn crypt_set_iv(slot : CryptSlot, value : @value.Cell) -> Unit raise EvalError {
  match value {
    @value.None => {
      if slot.cbc {
        slot.iv = []
        slot.iv_ready = false
      }
      if slot.chacha {
        chacha_clear(slot)
      }
      if slot.poly {
        poly_set_iv(slot, [])
      }
      if slot.ccm {
        ccm_set_iv(slot, [])
      }
    }
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let bytes = bytes_from(series, index)
      if slot.cbc {
        if bytes.length() != 16 {
          raise EvalError::Cannot("modify")
        }
        slot.iv = bytes
        slot.iv_ready = true
      }
      if slot.chacha && bytes.length() > 0 {
        chacha_set_iv(slot, bytes)
      }
      if slot.poly && bytes.length() > 0 {
        poly_set_iv(slot, bytes)
      }
      if slot.ccm && bytes.length() > 0 {
        ccm_set_iv(slot, bytes)
      }
    }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
/// Pads a short block with zeros, then encrypts or decrypts it.
fn crypt_update(port : @value.Cell) -> @value.Cell raise EvalError {
  let slot = crypt_slot(port)
  if slot.poly {
    poly_finish(slot)
    return port
  }
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
  if slot.chacha {
    chacha_absorb(slot, bytes)
    return
  }
  if slot.poly {
    poly_absorb(slot, bytes)
    return
  }
  if slot.ccm {
    ccm_absorb(slot, bytes)
    return
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
fn install_key(slot : CryptSlot, key : Array[Int]) -> Unit raise EvalError {
  if slot.chacha {
    slot.chacha_key = key
    chacha_rewind(slot)
  } else if slot.poly {
    slot.poly_key = key
    poly_reset(slot)
  } else if slot.ccm {
    slot.rounds = aes_rounds(key)
    slot.ccm_reset = true
  } else if slot.camellia && slot.key_len == 16 {
    slot.cam_enc = camellia128_subkeys(key)
    slot.cam_dec = camellia128_decrypt_keys(slot.cam_enc)
  } else if slot.camellia {
    slot.cam_enc = camellia192_subkeys(key)
    slot.cam_dec = camellia192_decrypt_keys(slot.cam_enc)
  } else {
    slot.rounds = aes_rounds(key)
  }
  slot.key_ready = true
  slot.pending = []
}

///|
fn crypt_block(slot : CryptSlot) -> Array[Int] raise EvalError {
  if !slot.cbc {
    raw_block(slot, slot.pending)
  } else if !slot.iv_ready {
    raise EvalError::Cannot("write")
  } else if slot.encrypting {
    let mixed = chain_xor(slot.pending, slot.iv)
    let out = raw_block(slot, mixed)
    slot.iv = copy_block(out)
    out
  } else {
    let plain = raw_block(slot, slot.pending)
    let out = chain_xor(plain, slot.iv)
    slot.iv = copy_block(slot.pending)
    out
  }
}

///|
fn raw_block(slot : CryptSlot, block : Array[Int]) -> Array[Int] {
  if slot.chacha {
    chacha_apply(slot, block)
  } else if slot.camellia && slot.key_len == 16 {
    let keys = if slot.encrypting { slot.cam_enc } else { slot.cam_dec }
    camellia128_crypt(keys, block)
  } else if slot.camellia {
    let keys = if slot.encrypting { slot.cam_enc } else { slot.cam_dec }
    camellia192_crypt(keys, block)
  } else if slot.encrypting {
    aes_encrypt(slot.rounds, block)
  } else {
    aes_decrypt(slot.rounds, block)
  }
}

///|
/// A short write stays buffered. Once 16 bytes are in hand, the rest of that
/// write is encrypted, including a tail shorter than 16.
fn chacha_absorb(slot : CryptSlot, bytes : Array[Int]) -> Unit {
  if slot.pending.length() == 0 && bytes.length() >= 16 {
    chacha_emit(slot, chacha_apply(slot, bytes))
    return
  }
  let mut index = 0
  while index < bytes.length() && slot.pending.length() < 16 {
    slot.pending.push(bytes[index])
    index = index + 1
  }
  if slot.pending.length() < 16 {
    return
  }
  chacha_emit(slot, chacha_apply(slot, slot.pending))
  slot.pending = []
  let rest = bytes.length() - index
  if rest >= 16 {
    let tail : Array[Int] = []
    while index < bytes.length() {
      tail.push(bytes[index])
      index = index + 1
    }
    chacha_emit(slot, chacha_apply(slot, tail))
  } else {
    while index < bytes.length() {
      slot.pending.push(bytes[index])
      index = index + 1
    }
  }
}

///|
fn chacha_apply(slot : CryptSlot, data : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for byte in data {
    if slot.chacha_off == 0 {
      slot.chacha_stream = chacha20_block(
        slot.chacha_key,
        slot.chacha_counter,
        slot.chacha_nonce,
      )
    }
    out.push(byte ^ slot.chacha_stream[slot.chacha_off])
    slot.chacha_off = slot.chacha_off + 1
    if slot.chacha_off == 64 {
      slot.chacha_off = 0
      slot.chacha_counter = slot.chacha_counter + 1UL
    }
  }
  out
}

///|
fn chacha_emit(slot : CryptSlot, bytes : Array[Int]) -> Unit {
  for byte in bytes {
    slot.output.push(byte)
  }
}

///|
fn chacha_set_iv(slot : CryptSlot, bytes : Array[Int]) -> Unit {
  let padded : Array[Int] = []
  let mut index = 0
  while index < 16 {
    padded.push(0)
    index = index + 1
  }
  let count = if bytes.length() > 16 { 16 } else { bytes.length() }
  index = 0
  while index < count {
    padded[index] = bytes[index]
    index = index + 1
  }
  let nonce : Array[Int] = []
  index = 0
  while index < 12 {
    nonce.push(padded[index])
    index = index + 1
  }
  slot.chacha_nonce = nonce
  slot.chacha_base = be32(padded, 12)
  chacha_rewind(slot)
  slot.pending = []
}

///|
fn chacha_clear(slot : CryptSlot) -> Unit {
  slot.chacha_nonce = zero_nonce()
  slot.chacha_base = 0UL
  chacha_rewind(slot)
  slot.pending = []
}

///|
fn chacha_rewind(slot : CryptSlot) -> Unit {
  slot.chacha_off = 0
  slot.chacha_counter = slot.chacha_base
  slot.chacha_stream = []
}

///|
fn chacha_blank(slot : CryptSlot) -> Unit {
  slot.chacha_key = []
  slot.chacha_nonce = zero_nonce()
  slot.chacha_base = 0UL
  slot.chacha_counter = 0UL
  slot.chacha_off = 0
  slot.chacha_stream = []
}

///|
fn zero_nonce() -> Array[Int] {
  let nonce : Array[Int] = []
  let mut index = 0
  while index < 12 {
    nonce.push(0)
    index = index + 1
  }
  nonce
}

///|
/// The first write is additional data and produces no output. Later writes
/// are the message. `update` appends the 16-byte tag.
fn poly_absorb(slot : CryptSlot, bytes : Array[Int]) -> Unit {
  if bytes.length() == 0 {
    return
  }
  if !slot.poly_started {
    poly_begin(slot, bytes)
  } else {
    chacha_emit(slot, poly_apply(slot, bytes))
  }
}

///|
fn poly_begin(slot : CryptSlot, aad : Array[Int]) -> Unit {
  slot.output = []
  slot.pending = []
  slot.poly_aad = aad
  slot.poly_cipher = []
  slot.poly_nonce = poly_nonce(slot.poly_iv, aad)
  slot.poly_counter = 1UL
  slot.poly_off = 0
  slot.poly_stream = []
  slot.poly_started = true
  slot.poly_done = false
}

///|
/// XOR the first eight additional-data bytes into the tail of the vector.
fn poly_nonce(iv : Array[Int], aad : Array[Int]) -> Array[Int] {
  let nonce = zero_nonce()
  let copied = if iv.length() > 12 { 12 } else { iv.length() }
  let mut index = 0
  while index < copied {
    nonce[index] = iv[index]
    index = index + 1
  }
  let mixed = if aad.length() > 8 { 8 } else { aad.length() }
  index = 0
  while index < mixed {
    let at = 12 - mixed + index
    nonce[at] = nonce[at] ^ aad[index]
    index = index + 1
  }
  nonce
}

///|
fn poly_apply(slot : CryptSlot, data : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for byte in data {
    if slot.poly_off == 0 {
      slot.poly_stream = chacha20_block(
        slot.poly_key,
        slot.poly_counter,
        slot.poly_nonce,
      )
    }
    let mixed = byte ^ slot.poly_stream[slot.poly_off]
    out.push(mixed)
    if slot.encrypting {
      slot.poly_cipher.push(mixed)
    } else {
      slot.poly_cipher.push(byte)
    }
    slot.poly_off = slot.poly_off + 1
    if slot.poly_off == 64 {
      slot.poly_off = 0
      slot.poly_counter = slot.poly_counter + 1UL
    }
  }
  out
}

///|
fn poly_finish(slot : CryptSlot) -> Unit raise EvalError {
  if !slot.key_ready {
    raise EvalError::Cannot("update")
  }
  if slot.poly_done {
    return
  }
  if !slot.poly_started {
    poly_begin(slot, [])
  }
  let tag = poly1305_tag(
    slot.poly_key,
    slot.poly_nonce,
    slot.poly_aad,
    slot.poly_cipher,
  )
  chacha_emit(slot, tag)
  slot.poly_done = true
}

///|
fn poly_set_iv(slot : CryptSlot, bytes : Array[Int]) -> Unit {
  let iv = zero_nonce()
  let copied = if bytes.length() > 12 { 12 } else { bytes.length() }
  let mut index = 0
  while index < copied {
    iv[index] = bytes[index]
    index = index + 1
  }
  slot.poly_iv = iv
  poly_reset(slot)
}

///|
fn poly_reset(slot : CryptSlot) -> Unit {
  slot.poly_aad = []
  slot.poly_cipher = []
  slot.poly_nonce = zero_nonce()
  slot.poly_counter = 1UL
  slot.poly_off = 0
  slot.poly_stream = []
  slot.poly_started = false
  slot.poly_done = false
  slot.pending = []
}

///|
fn poly_blank(slot : CryptSlot) -> Unit {
  slot.poly_key = []
  slot.poly_iv = zero_nonce()
  poly_reset(slot)
}

///|
fn crypt_count(value : @value.Cell) -> Int raise EvalError {
  match value {
    @value.Integer(number) =>
      if number < 0L {
        raise EvalError::Cannot("modify")
      } else {
        number.to_int()
      }
    _ => raise EvalError::Cannot("modify")
  }
}

///|
/// One write is one CCM message. The leading `aad-length` bytes are
/// additional data. Encrypt appends the tag; decrypt checks it and drops it.
fn ccm_absorb(slot : CryptSlot, bytes : Array[Int]) -> Unit raise EvalError {
  if bytes.length() == 0 {
    return
  }
  if slot.ccm_reset {
    slot.output = []
    slot.pending = []
    slot.ccm_reset = false
  }
  let tag_len = slot.ccm_tag
  let aad_len = slot.ccm_aad
  if !ccm_tag_ok(tag_len, aad_len) || aad_len > bytes.length() {
    raise EvalError::Cannot("write")
  }
  let mut body_len = bytes.length() - aad_len
  if !slot.encrypting && body_len < tag_len {
    raise EvalError::Cannot("write")
  }
  if !slot.encrypting {
    body_len = body_len - tag_len
  }
  let aad = slice_from(bytes, 0, aad_len)
  let body = slice_from(bytes, aad_len, body_len)
  let (out, tag) = ccm_message(
    slot.rounds,
    slot.ccm_iv,
    aad,
    body,
    tag_len,
    slot.encrypting,
  )
  if !slot.encrypting && tag_len > 0 {
    let given = slice_from(bytes, aad_len + body_len, tag_len)
    if !same_bytes(tag, given) {
      raise EvalError::Cannot("write")
    }
  }
  chacha_emit(slot, out)
  if slot.encrypting {
    chacha_emit(slot, tag)
  }
}

///|
fn ccm_tag_ok(tag_len : Int, aad_len : Int) -> Bool {
  if aad_len < 0 || aad_len >= 0xFF00 {
    false
  } else if tag_len == 0 {
    aad_len == 0
  } else {
    tag_len >= 4 && tag_len <= 16 && tag_len % 2 == 0
  }
}

///|
fn ccm_set_iv(slot : CryptSlot, bytes : Array[Int]) -> Unit {
  let mut len = if bytes.length() > 13 { 13 } else { bytes.length() }
  if len < 7 {
    len = 7
  }
  let iv : Array[Int] = []
  let mut index = 0
  while index < len {
    if index < bytes.length() {
      iv.push(bytes[index])
    } else {
      iv.push(0)
    }
    index = index + 1
  }
  slot.ccm_iv = iv
  slot.ccm_reset = true
}

///|
fn ccm_zeros() -> Array[Int] {
  let iv : Array[Int] = []
  let mut index = 0
  while index < 7 {
    iv.push(0)
    index = index + 1
  }
  iv
}

///|
fn same_bytes(left : Array[Int], right : Array[Int]) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    let mut index = 0
    let mut same = true
    while index < left.length() {
      if left[index] != right[index] {
        same = false
      }
      index = index + 1
    }
    same
  }
}

///|
fn crypt_alloc(
  decrypting : Bool,
  key_len : Int,
  cbc : Bool,
  camellia : Bool,
  chacha : Bool,
  poly : Bool,
  ccm : Bool,
) -> Int {
  let mut index = 0
  let mut found = -1
  while index < crypts.slots.length() && found < 0 {
    if !crypts.slots[index].live {
      found = index
    }
    index = index + 1
  }
  if found >= 0 {
    crypt_reset(
      crypts.slots[found],
      decrypting,
      key_len,
      cbc,
      camellia,
      chacha,
      poly,
      ccm,
    )
    found
  } else {
    let slot = crypt_fresh(
      decrypting, key_len, cbc, camellia, chacha, poly, ccm,
    )
    crypts.slots.push(slot)
    crypts.slots.length() - 1
  }
}

///|
fn crypt_fresh(
  decrypting : Bool,
  key_len : Int,
  cbc : Bool,
  camellia : Bool,
  chacha : Bool,
  poly : Bool,
  ccm : Bool,
) -> CryptSlot {
  {
    live: true,
    encrypting: !decrypting,
    key_ready: false,
    key_len,
    cbc,
    camellia,
    cam_enc: [],
    cam_dec: [],
    chacha,
    chacha_key: [],
    chacha_nonce: zero_nonce(),
    chacha_base: 0UL,
    chacha_counter: 0UL,
    chacha_off: 0,
    chacha_stream: [],
    poly,
    poly_key: [],
    poly_iv: zero_nonce(),
    poly_aad: [],
    poly_cipher: [],
    poly_nonce: zero_nonce(),
    poly_counter: 1UL,
    poly_off: 0,
    poly_stream: [],
    poly_started: false,
    poly_done: false,
    ccm,
    ccm_tag: 0,
    ccm_aad: 0,
    ccm_iv: ccm_zeros(),
    ccm_reset: true,
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
  camellia : Bool,
  chacha : Bool,
  poly : Bool,
  ccm : Bool,
) -> Unit {
  slot.live = true
  slot.encrypting = !decrypting
  slot.key_ready = false
  slot.key_len = key_len
  slot.cbc = cbc
  slot.camellia = camellia
  slot.cam_enc = []
  slot.cam_dec = []
  slot.chacha = chacha
  slot.poly = poly
  slot.ccm = ccm
  slot.ccm_tag = 0
  slot.ccm_aad = 0
  slot.ccm_iv = ccm_zeros()
  slot.ccm_reset = true
  chacha_blank(slot)
  poly_blank(slot)
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
      install_key(slot, key)
    }
    _ => raise EvalError::Cannot("open")
  }
}

///|
fn crypt_use_iv(slot : CryptSlot, value : @value.Cell) -> Unit raise EvalError {
  match value {
    @value.None => {
      if slot.chacha {
        chacha_clear(slot)
      }
      if slot.poly {
        poly_set_iv(slot, [])
      }
      if slot.ccm {
        ccm_set_iv(slot, [])
      }
    }
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let bytes = bytes_from(series, index)
      if slot.cbc {
        if bytes.length() != 16 {
          raise EvalError::Cannot("open")
        }
        slot.iv = bytes
        slot.iv_ready = true
      }
      if slot.chacha && bytes.length() > 0 {
        chacha_set_iv(slot, bytes)
      }
      if slot.poly && bytes.length() > 0 {
        poly_set_iv(slot, bytes)
      }
      if slot.ccm && bytes.length() > 0 {
        ccm_set_iv(slot, bytes)
      }
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
