///|
/// SAFE 1.0, as in codec-safe.reb. A binary is stored as itself. Anything else
/// is molded, then zlib-compressed. The cipher is aes-192-gcm. The key is the
/// first 24 bytes of SHA-256 of the password, and the vector is the first 16
/// header bytes. A bad header or password is none.
fn encode_safe(
  env : Env,
  value : @value.Cell,
  password : String,
) -> @value.Cell raise EvalError {
  let (flags, payload) = safe_payload(value)
  binary_cell(safe_pack(env, flags, payload, safe_key(password)))
}

///|
fn decode_safe(
  env : Env,
  value : @value.Cell,
  password : String,
) -> @value.Cell raise EvalError {
  let bytes = payload_bytes(value, "decode")
  match safe_unpack(env, bytes, safe_key(password)) {
    None => @value.Cell::None
    Some((flags, plain)) => safe_restore(env, flags, plain)
  }
}

///|
fn safe_payload(value : @value.Cell) -> (Int, Array[Int]) raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      (0, bytes_from(series, index))
    _ => (3, save_zlib(@mold.mold_text(value)))
  }
}

///|
fn safe_restore(
  env : Env,
  flags : Int,
  plain : Array[Int],
) -> @value.Cell raise EvalError {
  if flags == 0 {
    binary_cell(plain)
  } else if flags == 3 {
    let packed = c_zlib_decompress(latin_text(plain), plain.length(), 15)
    if c_zlib_code() != 0 {
      @value.Cell::None
    } else {
      singular(load(env, qp_text(codes_of(packed))))
    }
  } else {
    @value.Cell::None
  }
}

///|
fn safe_pack(
  env : Env,
  flags : Int,
  payload : Array[Int],
  key : Array[Int],
) -> Array[Int] raise EvalError {
  let head = safe_head(flags, payload.length(), sha256(payload))
  let out = head
  let cipher_name = "aes-192-gcm"
  out.push(cipher_name.length())
  for char in cipher_name {
    out.push(char.to_int())
  }
  if payload.length() == 0 {
    safe_push(out, 0, 4)
  } else {
    let cipher = safe_gcm(env, key, safe_iv(head), payload, false)
    safe_push(out, cipher.length(), 4)
    for byte in cipher {
      out.push(byte)
    }
  }
  out
}

///|
fn safe_unpack(
  env : Env,
  bytes : Array[Int],
  key : Array[Int],
) -> (Int, Array[Int])? raise EvalError {
  if !safe_id(bytes) {
    None
  } else {
    let flags = safe_read(bytes, 8, 2)
    let size = safe_read(bytes, 10, 4)
    let sum = safe_slice(bytes, 14, 32)
    let name_at = 46
    if name_at >= bytes.length() {
      None
    } else {
      let name_len = bytes[name_at]
      let cipher_name = safe_slice(bytes, name_at + 1, name_len)
      let cipher_at = name_at + 1 + name_len
      if safe_text(cipher_name) != "aes-192-gcm" ||
        cipher_at + 4 > bytes.length() {
        None
      } else {
        let cipher_len = safe_read(bytes, cipher_at, 4)
        let cipher = safe_slice(bytes, cipher_at + 4, cipher_len)
        if cipher.length() != cipher_len {
          None
        } else {
          let plain = if cipher_len == 0 {
            []
          } else {
            safe_gcm(env, key, safe_iv(bytes), cipher, true)
          }
          if !same_bytes(sha256(plain), sum) {
            None
          } else if size < 0 || size > plain.length() {
            None
          } else {
            Some((flags, safe_slice(plain, 0, size)))
          }
        }
      }
    }
  }
}

///|
fn safe_head(flags : Int, size : Int, sum : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for char in "SAFE 1.0" {
    out.push(char.to_int())
  }
  safe_push(out, flags, 2)
  safe_push(out, size, 4)
  for byte in sum {
    out.push(byte)
  }
  out
}

///|
fn safe_id(bytes : Array[Int]) -> Bool {
  bytes.length() >= 46 && safe_text(safe_slice(bytes, 0, 8)) == "SAFE 1.0"
}

///|
fn safe_iv(bytes : Array[Int]) -> Array[Int] {
  safe_slice(bytes, 0, 16)
}

///|
fn safe_secret(cell : @value.Cell) -> String raise EvalError {
  match cell {
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      text_from(series, index)
    _ => raise EvalError::Cannot("encode")
  }
}

///|
fn safe_key(password : String) -> Array[Int] {
  safe_slice(sha256(utf8_bytes(password)), 0, 24)
}

///|
fn safe_gcm(
  env : Env,
  key : Array[Int],
  iv : Array[Int],
  data : Array[Int],
  decrypt : Bool,
) -> Array[Int] raise EvalError {
  let direction = if decrypt { " direction: 'decrypt" } else { "" }
  let source = "(read write open make port! [scheme: 'crypt algorithm: 'aes-192-gcm key: #{" +
    byte_hex(key) +
    "} init-vector: #{" +
    byte_hex(iv) +
    "}" +
    direction +
    "] #{" +
    byte_hex(data) +
    "})"
  match run(env, source) {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => raise EvalError::Cannot("encode")
  }
}

///|
fn byte_hex(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  for byte in bytes {
    buf.write_char(hex_digit(byte / 16))
    buf.write_char(hex_digit(byte % 16))
  }
  buf.to_string()
}

///|
fn safe_text(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  for byte in bytes {
    match byte.to_char() {
      Some(char) => buf.write_char(char)
      None => ()
    }
  }
  buf.to_string()
}

///|
fn safe_slice(bytes : Array[Int], at : Int, size : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index < size && at + index < bytes.length() {
    out.push(bytes[at + index])
    index = index + 1
  }
  out
}

///|
fn safe_push(out : Array[Int], value : Int, width : Int) -> Unit {
  let mut shift = (width - 1) * 8
  while shift >= 0 {
    out.push((value >> shift) & 255)
    shift = shift - 8
  }
}

///|
fn safe_read(bytes : Array[Int], at : Int, width : Int) -> Int {
  let mut value = 0
  let mut index = 0
  while index < width && at + index < bytes.length() {
    value = (value << 8) + bytes[at + index]
    index = index + 1
  }
  value
}
