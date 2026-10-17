///|
/// Turns a string or a binary into base-85, base-64, base-36, base-16, or base-2 text.
/// `/part` limits how many characters or bytes are encoded.
fn perform_enbase(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let (part, url) = base_flags(env, args, active, "enbase")
  let bytes = ranged_payload(args[0], part, "enbase")
  match coding_base(args[1]) {
    Some(85) => text_series(encode_base85(bytes))
    Some(64) => text_series(encode_base64(bytes, url))
    Some(36) => text_series(encode_base36(bytes))
    Some(16) => text_series(encode_base16(bytes))
    Some(2) => text_series(encode_base2(bytes))
    _ => raise EvalError::Cannot("enbase")
  }
}

///|
/// Turns base-85, base-64, base-36, base-16, or base-2 text back into a binary.
/// Spaces and line breaks are skipped. `/part` limits the input.
fn perform_debase(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let (part, _) = base_flags(env, args, active, "debase")
  let text = latin_text(ranged_payload(args[0], part, "debase"))
  match coding_base(args[1]) {
    Some(85) => binary_cell(decode_base85(text))
    Some(64) => binary_cell(decode_base64(text))
    Some(36) => binary_cell(decode_base36(text))
    Some(16) => binary_cell(decode_base16(text))
    Some(2) => binary_cell(decode_base2(text))
    _ => raise EvalError::Cannot("debase")
  }
}

///|
/// `/part` takes one length. `/url` selects the URL alphabet. `/flat` is accepted
/// because the result is already one line.
fn base_flags(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
  action : String,
) -> (Int?, Bool) raise EvalError {
  let mut part : Int? = None
  let mut url = false
  let mut cursor = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "part" {
      part = Some(part_count(args[0], args[cursor], action))
      cursor = cursor + 1
    } else if name == "url" {
      url = true
    } else if name == "flat" {
      ()
    } else {
      raise EvalError::Cannot(action)
    }
  }
  (part, url)
}

///|
fn coding_base(base : @value.Cell) -> Int? {
  match base {
    @value.Integer(85L) => Some(85)
    @value.Integer(64L) => Some(64)
    @value.Integer(36L) => Some(36)
    @value.Integer(16L) => Some(16)
    @value.Integer(2L) => Some(2)
    _ => None
  }
}

///|
fn payload_bytes(
  value : @value.Cell,
  action : String,
) -> Array[Int] raise EvalError {
  match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      utf8_bytes(text_from(series, index))
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => raise EvalError::Cannot(action)
  }
}

///|
fn bytes_from(series : @value.Series, index : Int) -> Array[Int] {
  let bytes : Array[Int] = []
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.byte_at(cursor) {
      Some(byte) => bytes.push(byte.to_int())
      None => ()
    }
    cursor = cursor + 1
  }
  bytes
}

///|
fn utf8_bytes(text : String) -> Array[Int] {
  let bytes : Array[Int] = []
  for char in text {
    push_utf8(bytes, char.to_int())
  }
  bytes
}

///|
fn push_utf8(bytes : Array[Int], code : Int) -> Unit {
  if code < 0x80 {
    bytes.push(code)
  } else if code < 0x800 {
    bytes.push(0xC0 + code / 64)
    bytes.push(0x80 + code % 64)
  } else if code < 0x10000 {
    bytes.push(0xE0 + code / 4096)
    bytes.push(0x80 + code / 64 % 64)
    bytes.push(0x80 + code % 64)
  } else {
    bytes.push(0xF0 + code / 262144)
    bytes.push(0x80 + code / 4096 % 64)
    bytes.push(0x80 + code / 64 % 64)
    bytes.push(0x80 + code % 64)
  }
}

///|
fn latin_text(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  for byte in bytes {
    buf.write_char(byte.to_char().unwrap())
  }
  buf.to_string()
}

///|
fn binary_cell(bytes : Array[Int]) -> @value.Cell {
  let series = @value.Series::binary()
  for byte in bytes {
    series.push_byte(byte.to_byte()) |> ignore
  }
  @value.Seq(series, 0)
}

///|
/// Base 36 reads the bytes as one big-endian integer of at most eight bytes.
fn encode_base36(bytes : Array[Int]) -> String raise EvalError {
  if bytes.length() > 8 {
    raise EvalError::Cannot("enbase")
  }
  if bytes.length() == 0 {
    return ""
  }
  let mut value = 0UL
  for byte in bytes {
    value = (value << 8) | byte.to_uint64()
  }
  let powers = base36_powers()
  let buf = StringBuilder()
  let mut started = false
  let mut rest = value
  for place in 0..<13 {
    let power = powers[12 - place]
    let digit = rest / power
    rest = rest - power * digit
    if started || digit != 0UL || place == 12 {
      started = true
      buf.write_char(base36_char(digit.to_int()))
    }
  }
  buf.to_string()
}

///|
fn decode_base36(text : String) -> Array[Int] raise EvalError {
  if text.length() > 13 {
    raise EvalError::Cannot("debase")
  }
  if text.length() == 0 {
    return []
  }
  let powers = base36_powers()
  let mut value = 0UL
  let mut index = 0
  while index < text.length() {
    let digit = base36_digit(text[index].to_int())
    let power = powers[text.length() - index - 1]
    value = base36_add(value, digit, power)
    index = index + 1
  }
  let out : Array[Int] = []
  let mut shift = 56
  while shift >= 0 {
    out.push(((value >> shift) & 0xFFUL).to_int())
    shift = shift - 8
  }
  out
}

///|
fn base36_add(
  value : UInt64,
  digit : Int,
  power : UInt64,
) -> UInt64 raise EvalError {
  let wide = digit.to_uint64()
  if wide != 0UL && power != 0UL && wide > 0xFFFFFFFFFFFFFFFFUL / power {
    raise EvalError::Cannot("debase")
  }
  let add = wide * power
  if value > 0xFFFFFFFFFFFFFFFFUL - add {
    raise EvalError::Cannot("debase")
  }
  value + add
}

///|
fn base36_char(digit : Int) -> Char {
  if digit < 10 {
    ('0'.to_int() + digit).to_char().unwrap()
  } else {
    ('A'.to_int() + digit - 10).to_char().unwrap()
  }
}

///|
fn base36_digit(code : Int) -> Int raise EvalError {
  if code >= '0'.to_int() && code <= '9'.to_int() {
    code - '0'.to_int()
  } else if code >= 'A'.to_int() && code <= 'Z'.to_int() {
    code - 'A'.to_int() + 10
  } else if code >= 'a'.to_int() && code <= 'z'.to_int() {
    code - 'a'.to_int() + 10
  } else {
    raise EvalError::Cannot("debase")
  }
}

///|
fn base36_powers() -> Array[UInt64] {
  [
    1UL, 36UL, 1296UL, 46656UL, 1679616UL, 60466176UL, 2176782336UL, 78364164096UL,
    2821109907456UL, 101559956668416UL, 3656158440062976UL, 131621703842267136UL,
    4738381338321616896UL,
  ]
}

///|
fn encode_base85(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  while index + 3 < bytes.length() {
    let chunk = (bytes[index].to_int64() << 24) |
      (bytes[index + 1].to_int64() << 16) |
      (bytes[index + 2].to_int64() << 8) |
      bytes[index + 3].to_int64()
    if chunk == 0L {
      buf.write_char('z')
    } else {
      write_base85(buf, chunk, 5)
    }
    index = index + 4
  }
  let rest = bytes.length() - index
  if rest > 0 {
    let mut chunk = bytes[index].to_int64() << 24
    if rest > 1 {
      chunk = chunk | (bytes[index + 1].to_int64() << 16)
    }
    if rest > 2 {
      chunk = chunk | (bytes[index + 2].to_int64() << 8)
    }
    write_base85(buf, chunk, rest + 1)
  }
  buf.to_string()
}

///|
fn write_base85(buf : StringBuilder, chunk : Int64, count : Int) -> Unit {
  let digits : Array[Int] = [0, 0, 0, 0, 0]
  let mut value = chunk
  for place in 0..<5 {
    digits[4 - place] = (value % 85L).to_int()
    value = value / 85L
  }
  for cursor in 0..<count {
    buf.write_char((33 + digits[cursor]).to_char().unwrap())
  }
}

///|
fn decode_base85(text : String) -> Array[Int] raise EvalError {
  let chars : Array[Char] = []
  for char in text {
    if !is_b85_space(char) {
      chars.push(char)
    }
  }
  let out : Array[Int] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == 'z' {
      out.push(0)
      out.push(0)
      out.push(0)
      out.push(0)
      index = index + 1
    } else {
      let (chunk, pad, next) = base85_group(chars, index)
      let produced = [
        ((chunk >> 24) & 0xFFL).to_int(),
        ((chunk >> 16) & 0xFFL).to_int(),
        ((chunk >> 8) & 0xFFL).to_int(),
        (chunk & 0xFFL).to_int(),
      ]
      let keep = 4 - pad
      for cursor in 0..<keep {
        out.push(produced[cursor])
      }
      index = next
    }
  }
  out
}

///|
fn base85_group(
  chars : Array[Char],
  start : Int,
) -> (Int64, Int, Int) raise EvalError {
  let mut chunk = 0L
  let mut pad = 0
  let mut index = start
  for place in 0..<5 {
    let digit = if index < chars.length() {
      let value = base85_digit(chars[index])
      index = index + 1
      value
    } else {
      if pad == 0 {
        chunk = chunk + 1L
      }
      pad = pad + 1
      0
    }
    if place == 4 {
      if chunk > 50529026L {
        raise EvalError::Cannot("debase")
      }
      chunk = chunk * 85L
      if chunk > 4294967295L - digit.to_int64() {
        raise EvalError::Cannot("debase")
      }
      chunk = chunk + digit.to_int64()
    } else {
      chunk = chunk * 85L + digit.to_int64()
    }
  }
  (chunk, pad, index)
}

///|
fn base85_digit(char : Char) -> Int raise EvalError {
  let code = char.to_int()
  if code >= '!'.to_int() && code <= 'u'.to_int() {
    code - '!'.to_int()
  } else {
    raise EvalError::Cannot("debase")
  }
}

///|
fn is_b85_space(char : Char) -> Bool {
  char == ' ' ||
  char == '\t' ||
  char == '\n' ||
  char == '\r' ||
  char == '\u{000C}'
}

///|
fn encode_base64(bytes : Array[Int], url : Bool) -> String {
  let buf = StringBuilder()
  let mut index = 0
  while index + 2 < bytes.length() {
    let first = bytes[index]
    let second = bytes[index + 1]
    let third = bytes[index + 2]
    buf.write_char(b64_char(first / 4, url))
    buf.write_char(b64_char(first % 4 * 16 + second / 16, url))
    buf.write_char(b64_char(second % 16 * 4 + third / 64, url))
    buf.write_char(b64_char(third % 64, url))
    index = index + 3
  }
  let rest = bytes.length() - index
  if rest == 1 {
    let first = bytes[index]
    buf.write_char(b64_char(first / 4, url))
    buf.write_char(b64_char(first % 4 * 16, url))
    if !url {
      buf.write_string("==")
    }
  } else if rest == 2 {
    let first = bytes[index]
    let second = bytes[index + 1]
    buf.write_char(b64_char(first / 4, url))
    buf.write_char(b64_char(first % 4 * 16 + second / 16, url))
    buf.write_char(b64_char(second % 16 * 4, url))
    if !url {
      buf.write_char('=')
    }
  }
  buf.to_string()
}

///|
fn b64_char(n : Int, url : Bool) -> Char {
  if n < 26 {
    ('A'.to_int() + n).to_char().unwrap()
  } else if n < 52 {
    ('a'.to_int() + n - 26).to_char().unwrap()
  } else if n < 62 {
    ('0'.to_int() + n - 52).to_char().unwrap()
  } else if n == 62 {
    if url {
      '-'
    } else {
      '+'
    }
  } else if url {
    '_'
  } else {
    '/'
  }
}

///|
fn decode_base64(text : String) -> Array[Int] raise EvalError {
  let digits : Array[Int] = []
  for char in text {
    if is_b64_space(char) {
      ()
    } else if char == '=' {
      break
    } else {
      match b64_value(char) {
        Some(value) => digits.push(value)
        None => raise EvalError::Cannot("debase")
      }
    }
  }
  if digits.length() % 4 == 1 {
    raise EvalError::Cannot("debase")
  }
  let bytes : Array[Int] = []
  let mut index = 0
  while index + 3 < digits.length() {
    let first = digits[index]
    let second = digits[index + 1]
    let third = digits[index + 2]
    let fourth = digits[index + 3]
    bytes.push(first * 4 + second / 16)
    bytes.push(second % 16 * 16 + third / 4)
    bytes.push(third % 4 * 64 + fourth)
    index = index + 4
  }
  let rest = digits.length() - index
  if rest == 2 {
    let first = digits[index]
    let second = digits[index + 1]
    bytes.push(first * 4 + second / 16)
  } else if rest == 3 {
    let first = digits[index]
    let second = digits[index + 1]
    let third = digits[index + 2]
    bytes.push(first * 4 + second / 16)
    bytes.push(second % 16 * 16 + third / 4)
  }
  bytes
}

///|
fn is_b64_space(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\n' || char == '\r'
}

///|
fn encode_base16(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  for byte in bytes {
    buf.write_char(hex_digit(byte / 16))
    buf.write_char(hex_digit(byte % 16))
  }
  buf.to_string()
}

///|
fn hex_digit(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).to_char().unwrap()
  } else {
    ('A'.to_int() + n - 10).to_char().unwrap()
  }
}

///|
fn decode_base16(text : String) -> Array[Int] raise EvalError {
  let digits : Array[Int] = []
  for char in text {
    if is_b64_space(char) {
      ()
    } else {
      match hex_value(char) {
        Some(value) => digits.push(value)
        None => raise EvalError::Cannot("debase")
      }
    }
  }
  if digits.length() % 2 != 0 {
    raise EvalError::Cannot("debase")
  }
  let bytes : Array[Int] = []
  let mut index = 0
  while index < digits.length() {
    bytes.push(digits[index] * 16 + digits[index + 1])
    index = index + 2
  }
  bytes
}

///|
fn hex_value(char : Char) -> Int? {
  let code = char.to_int()
  if char >= '0' && char <= '9' {
    Some(code - '0'.to_int())
  } else if char >= 'A' && char <= 'F' {
    Some(code - 'A'.to_int() + 10)
  } else if char >= 'a' && char <= 'f' {
    Some(code - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn encode_base2(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  for byte in bytes {
    let mut mask = 128
    while mask > 0 {
      if byte / mask % 2 == 1 {
        buf.write_char('1')
      } else {
        buf.write_char('0')
      }
      mask = mask / 2
    }
  }
  buf.to_string()
}

///|
fn decode_base2(text : String) -> Array[Int] raise EvalError {
  let digits : Array[Int] = []
  for char in text {
    if is_b64_space(char) {
      ()
    } else if char == '0' || char == '1' {
      digits.push(if char == '1' { 1 } else { 0 })
    } else {
      raise EvalError::Cannot("debase")
    }
  }
  if digits.length() % 8 != 0 {
    raise EvalError::Cannot("debase")
  }
  let bytes : Array[Int] = []
  let mut index = 0
  while index < digits.length() {
    let mut byte = 0
    for _ in 0..<8 {
      byte = byte * 2 + digits[index]
      index = index + 1
    }
    bytes.push(byte)
  }
  bytes
}

///|
fn b64_value(char : Char) -> Int? {
  let code = char.to_int()
  if char >= 'A' && char <= 'Z' {
    Some(code - 'A'.to_int())
  } else if char >= 'a' && char <= 'z' {
    Some(code - 'a'.to_int() + 26)
  } else if char >= '0' && char <= '9' {
    Some(code - '0'.to_int() + 52)
  } else if char == '+' || char == '-' {
    Some(62)
  } else if char == '/' || char == '_' {
    Some(63)
  } else {
    None
  }
}
