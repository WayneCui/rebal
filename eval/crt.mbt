///|
/// X.509 certificate, following codec-crt.reb.
/// PEM armor is accepted when the label is CERTIFICATE. The result is always
/// an object; a value that is not a certificate leaves the fields unset as none.
fn decode_crt(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let frame = certificate_frame(env)
  let bytes = certificate_bytes(value)
  match block_items(decode_der(env, binary_cell(bytes))) {
    Some(items) =>
      if items.length() == 2 && word_is(env, items[0], "sequence") {
        fill_certificate(env, frame, items[1])
      }
    None => ()
  }
  @value.Object(frame)
}

///|
fn certificate_bytes(value : @value.Cell) -> Array[Int] raise EvalError {
  let bytes = payload_bytes(value, "decode")
  match read_pem(latin_text(bytes)) {
    Some(pem) => if pem.label == "CERTIFICATE" { pem.bytes } else { bytes }
    None => bytes
  }
}

///|
fn certificate_frame(env : Env) -> @value.Frame {
  let frame = @value.Frame::new()
  let names = [
    "version", "serial-number", "fingerprint", "algorithm", "issuer", "valid-from",
    "valid-to", "subject", "public-key", "issuer-id", "subject-id", "extensions",
    "signature",
  ]
  for name in names {
    put_cert(env, frame, name, @value.None)
  }
  frame
}

///|
fn put_cert(
  env : Env,
  frame : @value.Frame,
  name : String,
  cell : @value.Cell,
) -> Unit {
  let slot = frame.ensure(env.symbols.intern(name))
  frame.set(slot, cell) |> ignore
}

///|
fn fill_certificate(
  env : Env,
  frame : @value.Frame,
  body : @value.Cell,
) -> Unit raise EvalError {
  match block_items(body) {
    None => ()
    Some(items) =>
      if items.length() >= 2 && word_is(env, items[0], "sequence") {
        match fill_tbs(env, frame, items[1]) {
          Some(first) => finish_signature(env, frame, items, first)
          None => ()
        }
      }
  }
}

///|
fn fill_tbs(
  env : Env,
  frame : @value.Frame,
  body : @value.Cell,
) -> Array[@value.Cell]? raise EvalError {
  let items = match block_items(body) {
    Some(found) => found
    None => return None
  }
  if items.length() < 14 {
    return None
  }
  if !word_is(env, items[0], "cs0") {
    return None
  }
  match version_of(items[1]) {
    Some(version) => put_cert(env, frame, "version", version)
    None => return None
  }
  if !word_is(env, items[2], "integer") {
    return None
  }
  put_cert(env, frame, "serial-number", items[3])
  if !word_is(env, items[4], "sequence") {
    return None
  }
  let algorithm = match read_algorithm(env, items[5]) {
    Some(found) => found
    None => return None
  }
  put_cert(env, frame, "algorithm", list_block(algorithm))
  if !word_is(env, items[6], "sequence") {
    return None
  }
  put_cert(env, frame, "issuer", read_name(env, items[7]))
  if !word_is(env, items[8], "sequence") {
    return None
  }
  match validity_of(env, items[9]) {
    Some(span) => {
      put_cert(env, frame, "valid-from", span.0)
      put_cert(env, frame, "valid-to", span.1)
    }
    None => return None
  }
  if !word_is(env, items[10], "sequence") {
    return None
  }
  put_cert(env, frame, "subject", read_name(env, items[11]))
  if !word_is(env, items[12], "sequence") {
    return None
  }
  match read_public_key(env, items[13]) {
    Some(key) => put_cert(env, frame, "public-key", key)
    None => return None
  }
  read_certificate_tail(env, frame, items)
  Some(algorithm)
}

///|
/// Optional issuer and subject ids, then the extension wrapper.
fn read_certificate_tail(
  env : Env,
  frame : @value.Frame,
  items : Array[@value.Cell],
) -> Unit raise EvalError {
  let mut index = 14
  let mut ids = 0
  while index + 1 < items.length() {
    if word_is(env, items[index], "bit_string") {
      if ids == 0 {
        put_cert(env, frame, "issuer-id", items[index + 1])
      } else if ids == 1 {
        put_cert(env, frame, "subject-id", items[index + 1])
      }
      ids = ids + 1
    } else if word_is(env, items[index], "cs3") {
      put_cert(env, frame, "extensions", read_extensions(env, items[index + 1]))
    }
    index = index + 2
  }
}

///|
fn read_extensions(
  env : Env,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let block = @value.Series::block()
  match block_items(body) {
    Some(items) =>
      if items.length() >= 2 && word_is(env, items[0], "sequence") {
        append_extensions(env, block, items[1])
      }
    None => ()
  }
  @value.Seq(block, 0)
}

///|
fn append_extensions(
  env : Env,
  block : @value.Series,
  body : @value.Cell,
) -> Unit raise EvalError {
  match block_items(body) {
    Some(items) => {
      let mut index = 0
      while index + 1 < items.length() {
        if word_is(env, items[index], "sequence") {
          append_extension(env, block, items[index + 1])
        }
        index = index + 2
      }
    }
    None => ()
  }
}

///|
fn append_extension(
  env : Env,
  block : @value.Series,
  body : @value.Cell,
) -> Unit raise EvalError {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 2 && word_is(env, items[0], "object_identifier") {
        let name = decode_oid(env, items[1])
        let mut cursor = 2
        let mut critical = false
        if cursor + 1 < items.length() &&
          word_is(env, items[cursor], "boolean") &&
          critical_flag(items[cursor + 1]) {
          critical = true
          cursor = cursor + 2
        }
        if cursor + 1 < items.length() &&
          word_is(env, items[cursor], "octet_string") {
          block.push_item(name) |> ignore
          let value = list_block([
            @value.Logic(critical),
            extension_value(env, items[cursor + 1]),
          ])
          block.push_item(value) |> ignore
        }
      }
    None => ()
  }
}

///|
fn critical_flag(cell : @value.Cell) -> Bool {
  match binary_of(cell) {
    Some(bytes) => bytes.length() == 1 && bytes[0] == 0xFF
    None => false
  }
}

///|
/// An octet that opens with SEQUENCE is decoded. The name is not rewritten:
/// the codec's `extKeyUsage` arm does not match `extendedKeyUsage`.
fn extension_value(
  env : Env,
  cell : @value.Cell,
) -> @value.Cell raise EvalError {
  match binary_of(cell) {
    Some(bytes) =>
      if bytes.length() > 0 && bytes[0] == 0x30 {
        let decoded = decode_der(env, cell)
        match decoded {
          @value.None => cell
          _ => decoded
        }
      } else {
        cell
      }
    None => cell
  }
}

///|
fn finish_signature(
  env : Env,
  frame : @value.Frame,
  items : Array[@value.Cell],
  first : Array[@value.Cell],
) -> Unit raise EvalError {
  if items.length() >= 4 && word_is(env, items[2], "sequence") {
    match read_algorithm(env, items[3]) {
      Some(second) =>
        if same_algorithm(first, second) {
          if first.length() == 1 {
            put_cert(env, frame, "algorithm", first[0])
          }
        } else {
          put_cert(env, frame, "algorithm", @value.None)
        }
      None => ()
    }
  }
  if items.length() >= 6 && word_is(env, items[4], "bit_string") {
    put_cert(env, frame, "signature", items[5])
  }
}

///|
fn version_of(body : @value.Cell) -> @value.Cell? {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 2 && word_named(items[0], "integer") {
        match binary_of(items[1]) {
          Some(bytes) => unsigned_integer(bytes)
          None => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn unsigned_integer(bytes : Array[Int]) -> @value.Cell? {
  if bytes.length() == 0 || bytes.length() > 8 {
    None
  } else {
    let mut value = 0L
    for byte in bytes {
      value = (value << 8) + byte.to_int64()
    }
    Some(@value.Integer(value))
  }
}

///|
fn validity_of(env : Env, body : @value.Cell) -> (@value.Cell, @value.Cell)? {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 4 &&
        word_is(env, items[0], "utc_time") &&
        word_is(env, items[2], "utc_time") &&
        is_date(items[1]) &&
        is_date(items[3]) {
        Some((items[1], items[3]))
      } else {
        None
      }
    None => None
  }
}

///|
fn is_date(cell : @value.Cell) -> Bool {
  match cell {
    @value.Date(_) => true
    _ => false
  }
}

///|
fn read_algorithm(
  env : Env,
  body : @value.Cell,
) -> Array[@value.Cell]? raise EvalError {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 2 && word_is(env, items[0], "object_identifier") {
        let found = [decode_oid(env, items[1])]
        if items.length() >= 4 && !word_is(env, items[2], "null") {
          found.push(items[3])
        }
        Some(found)
      } else {
        None
      }
    None => None
  }
}

///|
fn read_name(env : Env, body : @value.Cell) -> @value.Cell raise EvalError {
  let block = @value.Series::block()
  match block_items(body) {
    Some(items) => {
      let mut index = 0
      while index + 1 < items.length() {
        if word_is(env, items[index], "set") {
          append_rdn(env, block, items[index + 1])
        }
        index = index + 2
      }
    }
    None => ()
  }
  @value.Seq(block, 0)
}

///|
fn append_rdn(
  env : Env,
  block : @value.Series,
  body : @value.Cell,
) -> Unit raise EvalError {
  match block_items(body) {
    Some(items) => {
      let mut index = 0
      while index + 1 < items.length() {
        if word_is(env, items[index], "sequence") {
          append_attribute(env, block, items[index + 1])
        }
        index = index + 2
      }
    }
    None => ()
  }
}

///|
fn append_attribute(
  env : Env,
  block : @value.Series,
  body : @value.Cell,
) -> Unit raise EvalError {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 4 &&
        word_is(env, items[0], "object_identifier") &&
        is_text(items[3]) {
        match set_word_of(decode_oid(env, items[1])) {
          Some(name) => {
            block.push_item(name) |> ignore
            block.push_item(items[3]) |> ignore
          }
          None => ()
        }
      }
    None => ()
  }
}

///|
fn set_word_of(cell : @value.Cell) -> @value.Cell? {
  match cell {
    @value.Sym(_, lexeme) =>
      Some(
        @value.Sym(
          @value.SetWord,
          @value.Lexeme::make(lexeme.sym(), lexeme.spelling()),
        ),
      )
    _ => None
  }
}

///|
fn read_public_key(
  env : Env,
  body : @value.Cell,
) -> @value.Cell? raise EvalError {
  match block_items(body) {
    Some(items) =>
      if items.length() >= 4 &&
        word_is(env, items[0], "sequence") &&
        word_is(env, items[2], "bit_string") {
        match read_algorithm(env, items[1]) {
          Some(algorithm) => {
            let block = @value.Series::block()
            for part in algorithm {
              block.push_item(part) |> ignore
            }
            block.push_item(key_material(env, algorithm, items[3])) |> ignore
            Some(@value.Seq(block, 0))
          }
          None => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn key_material(
  env : Env,
  algorithm : Array[@value.Cell],
  bits : @value.Cell,
) -> @value.Cell raise EvalError {
  let rsa = match algorithm[0] {
    @value.Sym(_, lexeme) => env.symbols.canon(lexeme.sym()) == "rsaencryption"
    _ => false
  }
  if rsa {
    match rsa_components(env, bits) {
      Some(pair) => pair
      None => bits
    }
  } else {
    bits
  }
}

///|
/// The leading zero is the BIT STRING unused-bits count. codec-der.reb drops
/// one leading zero when the next byte is a SEQUENCE, which is this byte.
fn rsa_components(
  env : Env,
  bits : @value.Cell,
) -> @value.Cell? raise EvalError {
  match binary_of(bits) {
    None => None
    Some(bytes) => {
      let start = if bytes.length() >= 2 && bytes[0] == 0 && bytes[1] == 0x30 {
        1
      } else {
        0
      }
      match der_span(env, bytes, start, bytes.length()) {
        None => None
        Some(outer) =>
          if outer.length() >= 2 {
            match block_items(outer[1]) {
              Some(inner) =>
                if inner.length() >= 4 &&
                  word_named(inner[0], "integer") &&
                  word_named(inner[2], "integer") {
                  Some(list_block([inner[1], inner[3]]))
                } else {
                  None
                }
              None => None
            }
          } else {
            None
          }
      }
    }
  }
}

///|
fn same_algorithm(
  left : Array[@value.Cell],
  right : Array[@value.Cell],
) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    let mut index = 0
    let mut same = true
    while same && index < left.length() {
      same = same_cell(left[index], right[index])
      index = index + 1
    }
    same
  }
}

///|
fn same_cell(left : @value.Cell, right : @value.Cell) -> Bool {
  match (left, right) {
    (@value.Sym(_, a), @value.Sym(_, b)) => a.sym() == b.sym()
    (@value.None, @value.None) => true
    (@value.Seq(a, ai), @value.Seq(b, bi)) =>
      if a.datatype() == @value.Binary && b.datatype() == @value.Binary {
        bytes_equal(bytes_from(a, ai), bytes_from(b, bi))
      } else {
        false
      }
    _ => false
  }
}

///|
fn bytes_equal(left : Array[Int], right : Array[Int]) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    let mut index = 0
    let mut same = true
    while same && index < left.length() {
      if left[index] != right[index] {
        same = false
      }
      index = index + 1
    }
    same
  }
}

///|
fn list_block(items : Array[@value.Cell]) -> @value.Cell {
  let block = @value.Series::block()
  for item in items {
    block.push_item(item) |> ignore
  }
  @value.Seq(block, 0)
}

///|
fn block_items(cell : @value.Cell) -> Array[@value.Cell]? {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let items : Array[@value.Cell] = []
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(item) => items.push(item)
          None => ()
        }
        cursor = cursor + 1
      }
      Some(items)
    }
    _ => None
  }
}

///|
fn binary_of(cell : @value.Cell) -> Array[Int]? {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      Some(bytes_from(series, index))
    _ => None
  }
}

///|
fn is_text(cell : @value.Cell) -> Bool {
  match cell {
    @value.Seq(series, _) => @value.text_series(series.datatype())
    _ => false
  }
}

///|
fn word_is(env : Env, cell : @value.Cell, name : String) -> Bool {
  match cell {
    @value.Sym(_, lexeme) => env.symbols.canon(lexeme.sym()) == name
    _ => false
  }
}

///|
fn word_named(cell : @value.Cell, name : String) -> Bool {
  match cell {
    @value.Sym(_, lexeme) => lexeme.spelling().to_lower() == name
    _ => false
  }
}
