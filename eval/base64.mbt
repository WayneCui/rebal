///|
/// Turns a string or a binary into base-64 text. Only base 64 is accepted.
fn perform_enbase(
  value : @value.Cell,
  base : @value.Cell,
) -> @value.Cell raise EvalError {
  if !is_base64(base) {
    raise EvalError::Cannot("enbase")
  }
  text_series(encode_base64(payload_bytes(value, "enbase")))
}

///|
/// Turns base-64 text back into a binary. Spaces and line breaks are skipped.
fn perform_debase(
  value : @value.Cell,
  base : @value.Cell,
) -> @value.Cell raise EvalError {
  if !is_base64(base) {
    raise EvalError::Cannot("debase")
  }
  match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      binary_cell(decode_base64(text_from(series, index)))
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      binary_cell(decode_base64(latin_text(bytes_from(series, index))))
    _ => raise EvalError::Cannot("debase")
  }
}

///|
fn is_base64(base : @value.Cell) -> Bool {
  match base {
    @value.Integer(n) => n == 64L
    _ => false
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
fn encode_base64(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  while index + 2 < bytes.length() {
    let first = bytes[index]
    let second = bytes[index + 1]
    let third = bytes[index + 2]
    buf.write_char(b64_char(first / 4))
    buf.write_char(b64_char(first % 4 * 16 + second / 16))
    buf.write_char(b64_char(second % 16 * 4 + third / 64))
    buf.write_char(b64_char(third % 64))
    index = index + 3
  }
  let rest = bytes.length() - index
  if rest == 1 {
    let first = bytes[index]
    buf.write_char(b64_char(first / 4))
    buf.write_char(b64_char(first % 4 * 16))
    buf.write_string("==")
  } else if rest == 2 {
    let first = bytes[index]
    let second = bytes[index + 1]
    buf.write_char(b64_char(first / 4))
    buf.write_char(b64_char(first % 4 * 16 + second / 16))
    buf.write_char(b64_char(second % 16 * 4))
    buf.write_char('=')
  }
  buf.to_string()
}

///|
fn b64_char(n : Int) -> Char {
  if n < 26 {
    ('A'.to_int() + n).to_char().unwrap()
  } else if n < 52 {
    ('a'.to_int() + n - 26).to_char().unwrap()
  } else if n < 62 {
    ('0'.to_int() + n - 52).to_char().unwrap()
  } else if n == 62 {
    '+'
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
fn b64_value(char : Char) -> Int? {
  let code = char.to_int()
  if char >= 'A' && char <= 'Z' {
    Some(code - 'A'.to_int())
  } else if char >= 'a' && char <= 'z' {
    Some(code - 'a'.to_int() + 26)
  } else if char >= '0' && char <= '9' {
    Some(code - '0'.to_int() + 52)
  } else if char == '+' {
    Some(62)
  } else if char == '/' {
    Some(63)
  } else {
    None
  }
}
