///|
/// A script may start with `Rebol [header]`. `options: [compress]` means the
/// rest is either raw zlib or a `64#{...}` binary. `/header` keeps the header
/// object in front of the values; without one, that place is none.
/// `/all` returns the source as scanned, header included, and does not collapse
/// a single value.
fn load_bytes(
  env : Env,
  bytes : Array[Int],
  header : Bool,
  all : Bool,
) -> @value.Cell raise EvalError {
  if all {
    load(env, script_text(bytes))
  } else {
    match script_split(bytes) {
      Some((source, rest)) => {
        let limited = script_limited(env, source, rest)
        let body = if script_compresses(env, source) {
          let raw = script_inflate(limited)
          script_verify(env, source, raw)
          load(env, script_text(raw))
        } else {
          script_verify(env, source, limited)
          load(env, script_text(limited))
        }
        script_finish(env, body, Some(source), header)
      }
      None => script_finish(env, load(env, script_text(bytes)), None, header)
    }
  }
}

///|
fn script_finish(
  env : Env,
  body : @value.Cell,
  source : String?,
  header : Bool,
) -> @value.Cell raise EvalError {
  if !header {
    singular(body)
  } else {
    let block = @value.Series::block()
    match source {
      Some(text) => block.push_item(script_header(env, text)) |> ignore
      None => block.push_item(@value.Cell::None) |> ignore
    }
    match block_items(body) {
      Some(items) =>
        for item in items {
          block.push_item(item) |> ignore
        }
      None => block.push_item(body) |> ignore
    }
    @value.Seq(block, 0)
  }
}

///|
fn script_header(env : Env, source : String) -> @value.Cell raise EvalError {
  let frame = @value.Frame::new()
  let names = [
    "version", "title", "name", "type", "date", "file", "author", "needs", "options",
    "checksum",
  ]
  for name in names {
    script_put(env, frame, name, @value.Cell::None)
  }
  let mut saw_version = false
  let mut saw_title = false
  match script_fields(env, source) {
    Some(items) => {
      let mut index = 0
      while index + 1 < items.length() {
        match items[index] {
          @value.Sym(@value.SetWord, lexeme) => {
            let name = env.symbols.canon(lexeme.sym())
            let slot = frame.ensure(lexeme.sym())
            frame.set(slot, header_value(env, items[index + 1])) |> ignore
            if name == "version" {
              saw_version = true
            }
            if name == "title" {
              saw_title = true
            }
            index = index + 2
          }
          _ => index = index + 1
        }
      }
    }
    None => ()
  }
  if !saw_version {
    script_put(env, frame, "version", @value.Tuple([0, 0, 0]))
  }
  if !saw_title {
    script_put(env, frame, "title", text_series("Untitled"))
  }
  @value.Object(frame)
}

///|
/// A header is constructed, not evaluated. `true`, `on`, and `yes` are
/// logic true; `false`, `off`, and `no` are logic false; `none` is none.
fn header_value(env : Env, cell : @value.Cell) -> @value.Cell {
  match cell {
    @value.Sym(@value.Word, lexeme) =>
      match env.symbols.canon(lexeme.sym()) {
        "none" => @value.Cell::None
        "true" | "on" | "yes" => @value.Logic(true)
        "false" | "off" | "no" => @value.Logic(false)
        _ => cell
      }
    _ => cell
  }
}

///|
fn script_put(
  env : Env,
  frame : @value.Frame,
  name : String,
  cell : @value.Cell,
) -> Unit {
  let slot = frame.ensure(env.symbols.intern(name))
  frame.set(slot, cell) |> ignore
}

///|
fn script_fields(
  env : Env,
  source : String,
) -> Array[@value.Cell]? raise EvalError {
  match block_items(load(env, source)) {
    Some(outer) =>
      if outer.length() == 1 {
        block_items(outer[0])
      } else {
        None
      }
    None => None
  }
}

///|
/// `length:` counts bytes after one CR and one LF. Anything past that is
/// left unread. A length that is not an integer does not cut the body.
fn script_limited(
  env : Env,
  source : String,
  rest : Array[Int],
) -> Array[Int] raise EvalError {
  let mut cursor = 0
  if cursor < rest.length() && rest[cursor] == 13 {
    cursor = cursor + 1
  }
  if cursor < rest.length() && rest[cursor] == 10 {
    cursor = cursor + 1
  }
  match script_length(env, source) {
    Some(n) => {
      let end = if cursor + n > rest.length() {
        rest.length()
      } else {
        cursor + n
      }
      script_slice(rest, cursor, end)
    }
    None => script_slice(rest, cursor, rest.length())
  }
}

///|
/// A binary `checksum:` must be the SHA1 of the body bytes. Anything else
/// there, other than none, is rejected.
fn script_verify(
  env : Env,
  source : String,
  bytes : Array[Int],
) -> Unit raise EvalError {
  match script_checksum(env, source) {
    None => ()
    Some(expect) =>
      if !same_bytes(expect, sha1(bytes)) {
        raise EvalError::Caused("bad-checksum", "checksum")
      }
  }
}

///|
fn script_checksum(env : Env, source : String) -> Array[Int]? raise EvalError {
  match script_fields(env, source) {
    Some(items) => {
      let mut found : Array[Int]? = None
      let mut seen = false
      let mut index = 0
      while !seen && index + 1 < items.length() {
        match items[index] {
          @value.Sym(@value.SetWord, lexeme) if env.symbols.canon(lexeme.sym()) ==
            "checksum" => {
            seen = true
            let value = header_value(env, items[index + 1])
            match value {
              @value.Cell::None => ()
              _ =>
                match binary_of(value) {
                  Some(digest) => found = Some(digest)
                  None => raise EvalError::Caused("bad-checksum", "checksum")
                }
            }
          }
          _ => index = index + 1
        }
      }
      found
    }
    None => None
  }
}

///|
fn script_length(env : Env, source : String) -> Int? raise EvalError {
  match script_fields(env, source) {
    Some(items) => {
      let mut found : Int? = None
      let mut seen = false
      let mut index = 0
      while !seen && index + 1 < items.length() {
        match items[index] {
          @value.Sym(@value.SetWord, lexeme) if env.symbols.canon(lexeme.sym()) ==
            "length" => {
            seen = true
            match items[index + 1] {
              @value.Integer(n) if n >= 0L && n <= 2147483647L =>
                found = Some(n.to_int())
              @value.Integer(_) => raise EvalError::Cannot("load")
              _ => ()
            }
          }
          _ => index = index + 1
        }
      }
      found
    }
    None => None
  }
}

///|
fn script_compresses(env : Env, source : String) -> Bool raise EvalError {
  match script_fields(env, source) {
    Some(items) => {
      let mut found = false
      let mut index = 0
      while index + 1 < items.length() {
        match items[index] {
          @value.Sym(@value.SetWord, lexeme) =>
            if env.symbols.canon(lexeme.sym()) == "options" &&
              script_names(env, items[index + 1], "compress") {
              found = true
            }
          _ => ()
        }
        index = index + 1
      }
      found
    }
    None => false
  }
}

///|
fn script_names(env : Env, cell : @value.Cell, name : String) -> Bool {
  match block_items(cell) {
    Some(items) => {
      let mut found = false
      for item in items {
        if word_is(env, item, name) {
          found = true
        }
      }
      found
    }
    None => false
  }
}

///|
fn script_inflate(bytes : Array[Int]) -> Array[Int] raise EvalError {
  let start = script_skip(bytes, 0)
  if start >= bytes.length() {
    raise EvalError::Cannot("load")
  } else if bytes[start] == 0x78 {
    script_zlib(script_slice(bytes, start, bytes.length()))
  } else {
    script_zlib(
      script_base64(script_text(script_slice(bytes, start, bytes.length()))),
    )
  }
}

///|
fn script_zlib(bytes : Array[Int]) -> Array[Int] raise EvalError {
  let packed = c_zlib_decompress(latin_text(bytes), bytes.length(), 15)
  if c_zlib_code() != 0 {
    raise EvalError::Cannot("load")
  }
  codes_of(packed)
}

///|
fn script_base64(text : String) -> Array[Int] raise EvalError {
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  let start = script_skip(codes, 0)
  let mut end = codes.length()
  while end > start && script_space(codes[end - 1]) {
    end = end - 1
  }
  if start + 4 >= end ||
    codes[start] != '6'.to_int() ||
    codes[start + 1] != '4'.to_int() ||
    codes[start + 2] != '#'.to_int() ||
    codes[start + 3] != '{'.to_int() ||
    codes[end - 1] != '}'.to_int() {
    raise EvalError::Cannot("load")
  }
  let mid = script_text(script_slice(codes, start + 4, end - 1))
  decode_base64(mid) catch {
    _ => raise EvalError::Cannot("load")
  }
}

///|
fn script_text(bytes : Array[Int]) -> String raise EvalError {
  qp_text(bytes) catch {
    _ => raise EvalError::Cannot("load")
  }
}

///|
fn script_split(bytes : Array[Int]) -> (String, Array[Int])? {
  let mut cursor = script_skip(bytes, 0)
  if !script_rebol(bytes, cursor) {
    None
  } else {
    cursor = script_skip(bytes, cursor + 5)
    if cursor >= bytes.length() || bytes[cursor] != '['.to_int() {
      None
    } else {
      match script_bracket(bytes, cursor) {
        Some(end) =>
          Some(
            (
              script_plain(bytes, cursor, end),
              script_slice(bytes, end, bytes.length()),
            ),
          )
        None => None
      }
    }
  }
}

///|
fn script_rebol(bytes : Array[Int], at : Int) -> Bool {
  if at + 5 > bytes.length() {
    false
  } else {
    let name = "rebol"
    let mut ok = true
    let mut index = 0
    for char in name {
      if script_fold(bytes[at + index]) != char.to_int() {
        ok = false
      }
      index = index + 1
    }
    ok &&
    (
      at + 5 == bytes.length() ||
      script_space(bytes[at + 5]) ||
      bytes[at + 5] == '['.to_int()
    )
  }
}

///|
fn script_bracket(bytes : Array[Int], at : Int) -> Int? {
  let mut depth = 0
  let mut quote = false
  let mut brace = 0
  let mut cursor = at
  let mut end : Int? = None
  while end is None && cursor < bytes.length() {
    let byte = bytes[cursor]
    if quote {
      quote = byte != '"'.to_int()
    } else if brace > 0 {
      if byte == '{'.to_int() {
        brace = brace + 1
      } else if byte == '}'.to_int() {
        brace = brace - 1
      }
    } else if byte == '"'.to_int() {
      quote = true
    } else if byte == '{'.to_int() {
      brace = 1
    } else if byte == '['.to_int() {
      depth = depth + 1
    } else if byte == ']'.to_int() {
      depth = depth - 1
      if depth == 0 {
        end = Some(cursor + 1)
      }
    }
    cursor = cursor + 1
  }
  end
}

///|
fn script_plain(bytes : Array[Int], from : Int, until : Int) -> String {
  latin_text(script_slice(bytes, from, until))
}

///|
/// A binary script may start with the UTF-8 BOM. A string does not: that
/// character is source text.
fn drop_bom(bytes : Array[Int]) -> Array[Int] {
  if bytes.length() >= 3 &&
    bytes[0] == 0xEF &&
    bytes[1] == 0xBB &&
    bytes[2] == 0xBF {
    script_slice(bytes, 3, bytes.length())
  } else {
    bytes
  }
}

///|
fn script_slice(bytes : Array[Int], from : Int, until : Int) -> Array[Int] {
  let out : Array[Int] = []
  for index in from..<until {
    out.push(bytes[index])
  }
  out
}

///|
fn script_skip(bytes : Array[Int], at : Int) -> Int {
  let mut cursor = at
  while cursor < bytes.length() && script_space(bytes[cursor]) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn script_space(byte : Int) -> Bool {
  byte == ' '.to_int() ||
  byte == '\t'.to_int() ||
  byte == '\n'.to_int() ||
  byte == '\r'.to_int()
}

///|
fn script_fold(byte : Int) -> Int {
  if byte >= 'A'.to_int() && byte <= 'Z'.to_int() {
    byte + 32
  } else {
    byte
  }
}
