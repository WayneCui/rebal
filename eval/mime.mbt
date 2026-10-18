///|
/// Encode a header with UTF-8 base64 words of at most 17 code points.
/// A field that is only a name, a colon, and safe text is returned unchanged.
fn encode_mime_field(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) => {
      let text = text_from(series, index)
      let codes : Array[Int] = []
      for char in text {
        codes.push(char.to_int())
      }
      if mime_plain(codes) {
        value
      } else {
        typed_text(series.datatype(), mime_words(codes, true))
      }
    }
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let codes = bytes_from(series, index)
      if mime_plain(codes) {
        value
      } else {
        binary_cell(utf8_bytes(mime_words(codes, false)))
      }
    }
    _ => raise EvalError::Cannot("encode")
  }
}

///|
fn mime_plain(codes : Array[Int]) -> Bool {
  let mut plain = true
  for index in mime_prefix(codes)..<codes.length() {
    if !mime_safe(codes[index]) {
      plain = false
    }
  }
  plain
}

///|
fn mime_prefix(codes : Array[Int]) -> Int {
  let mut cursor = 0
  if cursor >= codes.length() || !mime_key(codes[cursor]) {
    return 0
  }
  while cursor < codes.length() && mime_key(codes[cursor]) {
    cursor = cursor + 1
  }
  if cursor >= codes.length() || codes[cursor] != ':'.to_int() {
    return 0
  }
  cursor = cursor + 1
  if cursor >= codes.length() || !mime_space(codes[cursor]) {
    return 0
  }
  while cursor < codes.length() && mime_space(codes[cursor]) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn mime_key(code : Int) -> Bool {
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
  code == '-'.to_int() ||
  code == '_'.to_int()
}

///|
fn mime_safe(code : Int) -> Bool {
  code == ' '.to_int() ||
  code == '\t'.to_int() ||
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int())
}

///|
fn mime_words(codes : Array[Int], textual : Bool) -> String {
  let start = mime_prefix(codes)
  let buf = StringBuilder()
  for index in 0..<start {
    buf.write_char(codes[index].to_char().unwrap())
  }
  let mut cursor = start
  while cursor < codes.length() {
    let mut end = cursor + 17
    if end > codes.length() {
      end = codes.length()
    }
    let chunk : Array[Int] = []
    for index in cursor..<end {
      if textual {
        push_utf8(chunk, codes[index])
      } else {
        chunk.push(codes[index])
      }
    }
    if cursor > start {
      buf.write_string("\r\n ")
    }
    buf.write_string("=?UTF-8?B?")
    buf.write_string(encode_base64(chunk, false))
    buf.write_string("?=")
    cursor = end
  }
  buf.to_string()
}

///|
/// MIME header field, as in codec-mime-field.reb.
/// An encoded word is `=?charset?Q?text?=` or `=?charset?B?text?=`.
/// A newline followed by spaces becomes one space, unless the next word is encoded.
fn decode_mime_field(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) => {
      let plain = mime_bytes(utf8_bytes(text_from(series, index)))
      typed_text(series.datatype(), qp_text(plain))
    }
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      binary_cell(mime_bytes(bytes_from(series, index)))
    _ => raise EvalError::Cannot("decode")
  }
}

///|
fn mime_bytes(bytes : Array[Int]) -> Array[Int] raise EvalError {
  let out : Array[Int] = []
  let mut cursor = 0
  while cursor < bytes.length() {
    if mime_mark(bytes[cursor]) {
      match mime_unfold(bytes, cursor) {
        Some((space, next)) => {
          if space {
            out.push(' '.to_int())
          }
          cursor = next
        }
        None =>
          match mime_word(bytes, cursor) {
            Some((decoded, next)) => {
              for byte in decoded {
                out.push(byte)
              }
              cursor = next
            }
            None => {
              out.push(bytes[cursor])
              cursor = cursor + 1
            }
          }
      }
    } else {
      out.push(bytes[cursor])
      cursor = cursor + 1
    }
  }
  out
}

///|
fn mime_mark(byte : Int) -> Bool {
  byte == '\r'.to_int() || byte == '\n'.to_int() || byte == '='.to_int()
}

///|
fn mime_unfold(bytes : Array[Int], at : Int) -> (Bool, Int)? {
  let width = if at + 1 < bytes.length() &&
    bytes[at] == '\r'.to_int() &&
    bytes[at + 1] == '\n'.to_int() {
    2
  } else if at + 1 < bytes.length() &&
    bytes[at] == '\n'.to_int() &&
    bytes[at + 1] == '\r'.to_int() {
    2
  } else if bytes[at] == '\n'.to_int() {
    1
  } else {
    0
  }
  if width == 0 {
    None
  } else {
    let mut cursor = at + width
    if cursor >= bytes.length() || !mime_space(bytes[cursor]) {
      None
    } else {
      while cursor < bytes.length() && mime_space(bytes[cursor]) {
        cursor = cursor + 1
      }
      let encoded = cursor + 1 < bytes.length() &&
        bytes[cursor] == '='.to_int() &&
        bytes[cursor + 1] == '?'.to_int()
      Some((!encoded, cursor))
    }
  }
}

///|
fn mime_space(byte : Int) -> Bool {
  byte == ' '.to_int() || byte == '\t'.to_int()
}

///|
fn mime_word(
  bytes : Array[Int],
  at : Int,
) -> (Array[Int], Int)? raise EvalError {
  if at + 1 >= bytes.length() ||
    bytes[at] != '='.to_int() ||
    bytes[at + 1] != '?'.to_int() {
    None
  } else {
    match mime_until(bytes, at + 2, '?'.to_int()) {
      None => None
      Some((charset, after_charset)) =>
        if after_charset + 1 >= bytes.length() {
          None
        } else {
          let enc = bytes[after_charset]
          let mark = bytes[after_charset + 1]
          if mark != '?'.to_int() || !mime_encoding(enc) {
            None
          } else {
            match mime_token(bytes, after_charset + 2) {
              None => None
              Some((text, next)) =>
                Some((mime_payload(charset, enc, text), mime_gap(bytes, next)))
            }
          }
        }
    }
  }
}

///|
fn mime_encoding(byte : Int) -> Bool {
  let folded = if byte >= 'A'.to_int() && byte <= 'Z'.to_int() {
    byte + ('a'.to_int() - 'A'.to_int())
  } else {
    byte
  }
  folded == 'q'.to_int() || folded == 'b'.to_int()
}

///|
fn mime_until(bytes : Array[Int], at : Int, mark : Int) -> (Array[Int], Int)? {
  let text : Array[Int] = []
  let mut cursor = at
  while cursor < bytes.length() && bytes[cursor] != mark {
    text.push(bytes[cursor])
    cursor = cursor + 1
  }
  if cursor >= bytes.length() {
    None
  } else {
    Some((text, cursor + 1))
  }
}

///|
fn mime_token(bytes : Array[Int], at : Int) -> (Array[Int], Int)? {
  let text : Array[Int] = []
  let mut cursor = at
  while cursor + 1 < bytes.length() &&
        !(bytes[cursor] == '?'.to_int() && bytes[cursor + 1] == '='.to_int()) {
    text.push(bytes[cursor])
    cursor = cursor + 1
  }
  if cursor + 1 >= bytes.length() {
    None
  } else {
    Some((text, cursor + 2))
  }
}

///|
fn mime_gap(bytes : Array[Int], at : Int) -> Int {
  let mut cursor = at
  while cursor < bytes.length() && mime_ws(bytes[cursor]) {
    cursor = cursor + 1
  }
  if cursor + 1 < bytes.length() &&
    bytes[cursor] == '='.to_int() &&
    bytes[cursor + 1] == '?'.to_int() {
    cursor
  } else {
    at
  }
}

///|
fn mime_ws(byte : Int) -> Bool {
  mime_space(byte) || byte == '\r'.to_int() || byte == '\n'.to_int()
}

///|
fn mime_payload(
  charset : Array[Int],
  enc : Int,
  text : Array[Int],
) -> Array[Int] raise EvalError {
  let folded = if enc >= 'A'.to_int() && enc <= 'Z'.to_int() {
    enc + ('a'.to_int() - 'A'.to_int())
  } else {
    enc
  }
  let raw = if folded == 'q'.to_int() {
    qp_bytes(text, true)
  } else {
    decode_base64(latin_text(text))
  }
  if mime_utf8(charset) {
    raw
  } else {
    mime_latin1(raw)
  }
}

///|
fn mime_utf8(charset : Array[Int]) -> Bool {
  let folded : Array[Int] = []
  for byte in charset {
    if byte >= 'A'.to_int() && byte <= 'Z'.to_int() {
      folded.push(byte + ('a'.to_int() - 'A'.to_int()))
    } else {
      folded.push(byte)
    }
  }
  latin_text(folded) == "utf-8"
}

///|
fn mime_latin1(bytes : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for byte in bytes {
    if byte < 0x80 {
      out.push(byte)
    } else {
      out.push(0xC0 + byte / 64)
      out.push(0x80 + byte % 64)
    }
  }
  out
}
