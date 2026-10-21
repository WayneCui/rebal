///|
/// The text codec is the native branch in sys-codec.reb. A binary is read as
/// UTF-8. Anything else is `mold/only`: a block loses its outer brackets, and
/// every other value is molded as usual. `/as` is accepted and ignored.
fn encode_text(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let text = qp_text(bytes_from(series, index)) catch {
        _ => raise EvalError::Cannot("encode")
      }
      text_series(text)
    }
    @value.Seq(series, _) if series.datatype() == @value.Block =>
      text_series(text_contents(@mold.mold_text(value)))
    _ => text_series(@mold.mold_text(value))
  }
}

///|
/// `to string!` joins a block without spaces. A binary prefers its BOM or
/// UTF-8; when that fails, each byte becomes one character (Oldes / R3).
/// Line endings stay as they are. `none` cannot be converted.
fn to_string(value : @value.Cell) -> @value.Cell raise EvalError {
  text_series(string_text(value))
}

///|
fn string_text(value : @value.Cell) -> String raise EvalError {
  match value {
    @value.Cell::None => raise EvalError::Caused("bad-make-arg", "string!")
    @value.Sym(_, lexeme) => lexeme.spelling()
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      string_utf8(value, bytes_from(series, index))
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => string_joined(series, index, "")
    @value.Seq(series, index) if series.datatype() == @value.Path ||
      series.datatype() == @value.SetPath => string_joined(series, index, "/")
    _ => @mold.form_text(value)
  }
}

///|
fn string_joined(
  series : @value.Series,
  index : Int,
  sep : String,
) -> String raise EvalError {
  let buf = StringBuilder()
  let mut cursor = if index < 0 { 0 } else { index }
  let mut first = true
  while cursor < series.length() {
    if !first && sep != "" {
      buf.write_string(sep)
    }
    first = false
    match series.item(cursor) {
      Some(item) => buf.write_string(string_text(item))
      None => ()
    }
    cursor = cursor + 1
  }
  buf.to_string()
}

///|
fn string_utf8(_value : @value.Cell, bytes : Array[Int]) -> String {
  try {
    decode_text(bytes)
  } catch {
    _ => latin1_text(bytes)
  }
}

///|
/// One code unit per byte. Used when a binary is not valid UTF-8 / BOM text.
fn latin1_text(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  for byte in bytes {
    match (byte & 0xFF).to_char() {
      Some(char) => buf.write_char(char)
      None => ()
    }
  }
  buf.to_string()
}

///|
/// `load/as 'text` is `decode 'text`. A BOM selects UTF-8, UTF-16, or UTF-32.
/// Without one, the bytes are UTF-8. CR, LF, CRLF, and LFCR become one line feed.
priv enum TextBom {
  Utf8
  Utf16(Bool)
  Utf32(Bool)
}

///|
fn load_text(source : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = match source {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => utf8_bytes(source_text(source))
  }
  text_series(fold_text(decode_text(bytes)))
}

///|
fn decode_text(bytes : Array[Int]) -> String raise EvalError {
  let (bom, start) = text_bom(bytes)
  let body = text_slice(bytes, start)
  match bom {
    Utf8 => qp_text(body) catch { _ => raise EvalError::Cannot("load") }
    Utf16(little) => utf16_text(body, little)
    Utf32(little) => utf32_text(body, little)
  }
}

///|
/// Little-endian is true. UTF-32 is recognized before UTF-16, because both can start `FF FE`.
fn text_bom(bytes : Array[Int]) -> (TextBom, Int) {
  if bytes.length() >= 3 &&
    bytes[0] == 0xEF &&
    bytes[1] == 0xBB &&
    bytes[2] == 0xBF {
    (Utf8, 3)
  } else if bytes.length() >= 4 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xFE &&
    bytes[2] == 0 &&
    bytes[3] == 0 {
    (Utf32(true), 4)
  } else if bytes.length() >= 4 &&
    bytes[0] == 0 &&
    bytes[1] == 0 &&
    bytes[2] == 0xFE &&
    bytes[3] == 0xFF {
    (Utf32(false), 4)
  } else if bytes.length() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
    (Utf16(true), 2)
  } else if bytes.length() >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
    (Utf16(false), 2)
  } else {
    (Utf8, 0)
  }
}

///|
fn text_slice(bytes : Array[Int], start : Int) -> Array[Int] {
  let rest : Array[Int] = []
  for index in start..<bytes.length() {
    rest.push(bytes[index])
  }
  rest
}

///|
fn utf16_text(bytes : Array[Int], little : Bool) -> String raise EvalError {
  let buf = StringBuilder()
  let mut index = 0
  while index < bytes.length() {
    if index + 2 > bytes.length() {
      raise EvalError::Cannot("load")
    }
    let unit = text_u16(bytes, index, little)
    index = index + 2
    let code = if unit >= 0xD800 && unit <= 0xDBFF {
      if index + 2 > bytes.length() {
        raise EvalError::Cannot("load")
      }
      let low = text_u16(bytes, index, little)
      index = index + 2
      if low < 0xDC00 || low > 0xDFFF {
        raise EvalError::Cannot("load")
      }
      0x10000 + (((unit - 0xD800) << 10) | (low - 0xDC00))
    } else if unit >= 0xDC00 && unit <= 0xDFFF {
      raise EvalError::Cannot("load")
    } else {
      unit
    }
    write_text_char(buf, code)
  }
  buf.to_string()
}

///|
fn utf32_text(bytes : Array[Int], little : Bool) -> String raise EvalError {
  let buf = StringBuilder()
  let mut index = 0
  while index < bytes.length() {
    if index + 4 > bytes.length() {
      raise EvalError::Cannot("load")
    }
    let code = text_u32(bytes, index, little)
    index = index + 4
    if code > 0x10FFFFL || (code >= 0xD800L && code <= 0xDFFFL) {
      raise EvalError::Cannot("load")
    }
    write_text_char(buf, code.to_int())
  }
  buf.to_string()
}

///|
fn write_text_char(buf : StringBuilder, code : Int) -> Unit raise EvalError {
  match code.to_char() {
    Some(char) => buf.write_char(char)
    None => raise EvalError::Cannot("load")
  }
}

///|
fn text_u16(bytes : Array[Int], at : Int, little : Bool) -> Int {
  if little {
    bytes[at] + bytes[at + 1] * 256
  } else {
    bytes[at] * 256 + bytes[at + 1]
  }
}

///|
fn text_u32(bytes : Array[Int], at : Int, little : Bool) -> Int64 {
  if little {
    bytes[at].to_int64() +
    bytes[at + 1].to_int64() * 256L +
    bytes[at + 2].to_int64() * 65536L +
    bytes[at + 3].to_int64() * 16777216L
  } else {
    bytes[at].to_int64() * 16777216L +
    bytes[at + 1].to_int64() * 65536L +
    bytes[at + 2].to_int64() * 256L +
    bytes[at + 3].to_int64()
  }
}

///|
fn fold_text(text : String) -> String {
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  let buf = StringBuilder()
  let mut index = 0
  while index < codes.length() {
    let code = codes[index]
    if code == 13 || code == 10 {
      buf.write_char('\n')
      index = index + 1
      if index < codes.length() &&
        codes[index] != code &&
        (codes[index] == 13 || codes[index] == 10) {
        index = index + 1
      }
    } else {
      match code.to_char() {
        Some(char) => buf.write_char(char)
        None => ()
      }
      index = index + 1
    }
  }
  buf.to_string()
}

///|
/// The string `encode 'text` would write. A block loses its outer brackets.
fn encoded_text(value : @value.Cell) -> String raise EvalError {
  match encode_text(value) {
    @value.Seq(series, index) => text_from(series, index)
    _ => raise EvalError::Cannot("save")
  }
}

///|
fn text_contents(molded : String) -> String {
  let mut count = 0
  for char in molded {
    let _ = char
    count = count + 1
  }
  if count < 2 {
    molded
  } else {
    let buf = StringBuilder()
    let mut index = 0
    for char in molded {
      if index > 0 && index + 1 < count {
        buf.write_char(char)
      }
      index = index + 1
    }
    buf.to_string()
  }
}
