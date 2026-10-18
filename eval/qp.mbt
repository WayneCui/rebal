///|
/// Quoted-printable, as in codec-quoted-printable.reb.
/// Encode keeps every byte from 0 through 127 except `=`, then folds a line
/// after 75 bytes. Decode drops a soft break before turning `=HH` back into a
/// byte. `/uri` writes a space as `_` and reads `_` as a space.
fn encode_quoted(
  value : @value.Cell,
  uri : Bool,
) -> @value.Cell raise EvalError {
  let bytes = match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      utf8_bytes(text_from(series, index))
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => raise EvalError::Cannot("encode")
  }
  let encoded = match
    @series.enhex_with(binary_cell(bytes), uri, '='.to_int(), Some(qp_safe())) {
    Some(@value.Seq(series, index)) => bytes_from(series, index)
    _ => raise EvalError::Cannot("encode")
  }
  let wrapped = qp_wrap(encoded)
  match value {
    @value.Seq(series, _) if @value.text_series(series.datatype()) =>
      typed_text(series.datatype(), qp_text(wrapped))
    _ => binary_cell(wrapped)
  }
}

///|
fn perform_encode(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut uri = false
  let mut form : @value.Cell? = None
  let mut pass : @value.Cell? = None
  let mut cursor = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "uri" {
      uri = true
    } else if name == "as" {
      form = Some(args[cursor])
      cursor = cursor + 1
    } else if name == "key" {
      pass = Some(args[cursor])
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("encode")
    }
  }
  let kind = match args[0] {
    @value.Sym(_, lexeme) => env.symbols.canon(lexeme.sym())
    _ => raise EvalError::Cannot("encode")
  }
  if kind == "quoted-printable" {
    if form is Some(_) {
      raise EvalError::Cannot("encode")
    }
    encode_quoted(args[1], uri)
  } else if kind == "mime-field" {
    if uri || form is Some(_) {
      raise EvalError::Cannot("encode")
    }
    encode_mime_field(args[1])
  } else if kind == "unixtime" {
    if uri {
      raise EvalError::Cannot("encode")
    }
    encode_unix(args[1], form)
  } else if kind == "json" {
    if uri || form is Some(_) {
      raise EvalError::Cannot("encode")
    }
    encode_json(env, args[1])
  } else if kind == "text" {
    if uri {
      raise EvalError::Cannot("encode")
    }
    let _ = form
    encode_text(args[1])
  } else if kind == "srt" {
    if uri || pass is Some(_) {
      raise EvalError::Cannot("encode")
    }
    let _ = form
    encode_srt(args[1])
  } else if kind == "csv" || kind == "tsv" {
    if uri || pass is Some(_) {
      raise EvalError::Cannot("encode")
    }
    let _ = form
    let delimiter = if kind == "tsv" { '\t'.to_int() } else { ','.to_int() }
    encode_csv(args[1], delimiter)
  } else if kind == "braille" {
    if uri || form is Some(_) || pass is Some(_) {
      raise EvalError::Cannot("encode")
    }
    encode_braille(args[1])
  } else if kind == "safe" {
    if uri || form is Some(_) {
      raise EvalError::Cannot("encode")
    }
    match pass {
      Some(secret) => encode_safe(env, args[1], safe_secret(secret, "encode"))
      None => raise EvalError::Cannot("encode")
    }
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn qp_safe() -> @value.Bitset {
  let set = @value.Bitset::make()
  set.fill(0, '='.to_int() - 1)
  set.fill('='.to_int() + 1, 127)
  set
}

///|
fn qp_wrap(bytes : Array[Int]) -> Array[Int] {
  let limit = 75
  let out : Array[Int] = []
  let mut cursor = 0
  while cursor + limit < bytes.length() && bytes.length() - (cursor + limit) > 1 {
    for offset in 0..<limit {
      out.push(bytes[cursor + offset])
    }
    out.push('='.to_int())
    out.push('\r'.to_int())
    out.push('\n'.to_int())
    cursor = cursor + limit
  }
  while cursor < bytes.length() {
    out.push(bytes[cursor])
    cursor = cursor + 1
  }
  out
}

///|
/// Quoted-printable, as in codec-quoted-printable.reb. Soft breaks disappear
/// before `=HH` is turned back into a byte. `/uri` reads `_` as a space.
fn decode_quoted(
  value : @value.Cell,
  uri : Bool,
) -> @value.Cell raise EvalError {
  match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) => {
      let plain = qp_bytes(utf8_bytes(text_from(series, index)), uri)
      typed_text(series.datatype(), qp_text(plain))
    }
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      binary_cell(qp_bytes(bytes_from(series, index), uri))
    _ => raise EvalError::Cannot("decode")
  }
}

///|
fn typed_text(datatype : @value.Datatype, text : String) -> @value.Cell {
  let series = @value.Series::text_of(datatype)
  for char in text {
    series.push_code(char.to_int()) |> ignore
  }
  @value.Seq(series, 0)
}

///|
fn qp_bytes(bytes : Array[Int], uri : Bool) -> Array[Int] {
  qp_unescape(qp_strip(bytes), uri)
}

///|
fn qp_strip(bytes : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  let mut cursor = 0
  while cursor < bytes.length() {
    if bytes[cursor] == '='.to_int() &&
      cursor + 1 < bytes.length() &&
      bytes[cursor + 1] == '\n'.to_int() {
      cursor = cursor + 2
    } else if bytes[cursor] == '='.to_int() &&
      cursor + 2 < bytes.length() &&
      bytes[cursor + 1] == '\r'.to_int() &&
      bytes[cursor + 2] == '\n'.to_int() {
      cursor = cursor + 3
    } else {
      out.push(bytes[cursor])
      cursor = cursor + 1
    }
  }
  out
}

///|
fn qp_unescape(bytes : Array[Int], uri : Bool) -> Array[Int] {
  let out : Array[Int] = []
  let mut cursor = 0
  while cursor < bytes.length() {
    if bytes[cursor] == '='.to_int() && cursor + 2 < bytes.length() {
      match (qp_hex(bytes[cursor + 1]), qp_hex(bytes[cursor + 2])) {
        (Some(high), Some(low)) => {
          out.push(high * 16 + low)
          cursor = cursor + 3
        }
        _ => {
          out.push(bytes[cursor])
          cursor = cursor + 1
        }
      }
    } else if uri && bytes[cursor] == '_'.to_int() {
      out.push(' '.to_int())
      cursor = cursor + 1
    } else {
      out.push(bytes[cursor])
      cursor = cursor + 1
    }
  }
  out
}

///|
fn qp_hex(byte : Int) -> Int? {
  if byte >= '0'.to_int() && byte <= '9'.to_int() {
    Some(byte - '0'.to_int())
  } else if byte >= 'A'.to_int() && byte <= 'F'.to_int() {
    Some(byte - 'A'.to_int() + 10)
  } else if byte >= 'a'.to_int() && byte <= 'f'.to_int() {
    Some(byte - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn qp_text(bytes : Array[Int]) -> String raise EvalError {
  let buf = StringBuilder()
  let mut cursor = 0
  while cursor < bytes.length() {
    let (code, next) = qp_utf8(bytes, cursor)
    match code.to_char() {
      Some(char) => buf.write_char(char)
      None => raise EvalError::Cannot("decode")
    }
    cursor = next
  }
  buf.to_string()
}

///|
fn qp_utf8(bytes : Array[Int], at : Int) -> (Int, Int) raise EvalError {
  let lead = bytes[at]
  if lead < 0x80 {
    (lead, at + 1)
  } else {
    let width = if lead < 0xE0 { 2 } else if lead < 0xF0 { 3 } else { 4 }
    let mut code = lead % (1 << (7 - width))
    if at + width > bytes.length() {
      raise EvalError::Cannot("decode")
    }
    for cursor in (at + 1)..<(at + width) {
      let byte = bytes[cursor]
      if byte < 0x80 || byte >= 0xC0 {
        raise EvalError::Cannot("decode")
      }
      code = code * 64 + byte % 64
    }
    (code, at + width)
  }
}
