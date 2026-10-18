///|
/// Portable Document Format, as in codec-pdf.reb. The result is an object
/// with the version, the file size, the trailer, the object map, the
/// cross-reference entries, and `startxref`. A name that cannot be a word,
/// such as one that contains a space, is kept as a string.
fn decode_pdf(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.File =>
      read_binary(text_from(series, index))
    _ => raise EvalError::Caused("expect-arg", "decode")
  }
  match pdf_document(env, bytes) {
    Some(document) => document
    None => @value.Cell::None
  }
}

///|
fn pdf_document(env : Env, bytes : Array[Int]) -> @value.Cell? raise EvalError {
  match pdf_header(bytes, 0) {
    None => None
    Some((version, start)) => {
      let mut at = start
      at = pdf_gap(bytes, at)
      at = pdf_one_comment(bytes, at)
      let objects = @value.MapValue::make()
      let refs = @value.Series::block()
      let mut trailer : @value.Cell = @value.Cell::None
      let mut start_at : @value.Cell = @value.Cell::None
      match pdf_body(env, bytes, at, objects, refs) {
        None => None
        Some((next, found_trailer, found_start)) => {
          at = pdf_gap(bytes, next)
          match found_trailer {
            Some(cell) => trailer = cell
            None => ()
          }
          match found_start {
            Some(cell) => start_at = cell
            None => ()
          }
          if !pdf_keyword(bytes, at, "%%EOF") {
            None
          } else {
            at = pdf_gap(bytes, at + 5)
            if at < bytes.length() {
              match pdf_body(env, bytes, at, objects, refs) {
                None => None
                Some((again, again_trailer, again_start)) => {
                  at = pdf_gap(bytes, again)
                  match again_trailer {
                    Some(cell) => trailer = cell
                    None => ()
                  }
                  match again_start {
                    Some(cell) => start_at = cell
                    None => ()
                  }
                  if !pdf_keyword(bytes, at, "%%EOF") {
                    None
                  } else {
                    pdf_finish(
                      env,
                      bytes,
                      version,
                      objects,
                      refs,
                      pdf_linearized(env, bytes, objects, refs, trailer),
                      start_at,
                    )
                  }
                }
              }
            } else {
              pdf_finish(
                env,
                bytes,
                version,
                objects,
                refs,
                pdf_linearized(env, bytes, objects, refs, trailer),
                start_at,
              )
            }
          }
        }
      }
    }
  }
}

///|
fn pdf_body(
  env : Env,
  bytes : Array[Int],
  at : Int,
  objects : @value.MapValue,
  refs : @value.Series,
) -> (Int, @value.Cell?, @value.Cell?)? raise EvalError {
  let mut cursor = at
  let mut reading = true
  while reading {
    cursor = pdf_gap(bytes, cursor)
    match pdf_object(env, bytes, cursor, objects) {
      Some((next, _)) => cursor = next
      None => reading = false
    }
  }
  let mut xref = true
  let mut failed = false
  while xref && !failed {
    cursor = pdf_gap(bytes, cursor)
    if pdf_keyword(bytes, cursor, "xref") {
      match pdf_xref(bytes, cursor, refs) {
        Some(next) => cursor = next
        None => {
          failed = true
          xref = false
        }
      }
    } else {
      xref = false
    }
  }
  if failed {
    None
  } else {
    cursor = pdf_gap(bytes, cursor)
    match pdf_tail(env, bytes, cursor, objects) {
      Some((next, trailer, start_at)) => Some((next, trailer, start_at))
      None => None
    }
  }
}

///|
fn pdf_finish(
  env : Env,
  bytes : Array[Int],
  version : String,
  objects : @value.MapValue,
  refs : @value.Series,
  trailer : @value.Cell,
  start_at : @value.Cell,
) -> @value.Cell? raise EvalError {
  let frame = @value.Frame::new()
  put_field(env, frame, "version", text_series(version))
  put_field(env, frame, "file-size", @value.Integer(bytes.length().to_int64()))
  put_field(env, frame, "trailer", trailer)
  put_field(env, frame, "objects", @value.Map(objects))
  put_field(env, frame, "referencies", @value.Seq(refs, 0))
  put_field(env, frame, "startxref", start_at)
  Some(@value.Object(frame))
}

///|
fn pdf_header(bytes : Array[Int], at : Int) -> (String, Int)? {
  if !pdf_keyword(bytes, at, "%PDF-") {
    return None
  }
  let mut cursor = at + 5
  let start = cursor
  if !pdf_digits_at(bytes, cursor) {
    return None
  }
  while cursor < bytes.length() && pdf_digit(bytes[cursor]) {
    cursor = cursor + 1
  }
  if cursor >= bytes.length() || bytes[cursor] != '.'.to_int() {
    return None
  }
  cursor = cursor + 1
  if !pdf_digits_at(bytes, cursor) {
    return None
  }
  while cursor < bytes.length() && pdf_digit(bytes[cursor]) {
    cursor = cursor + 1
  }
  let version = pdf_latin(bytes, start, cursor)
  cursor = pdf_spaces(bytes, cursor)
  match pdf_newline(bytes, cursor) {
    Some(next) => Some((version, next))
    None => None
  }
}

///|
fn pdf_one_comment(bytes : Array[Int], at : Int) -> Int {
  if at + 1 < bytes.length() &&
    bytes[at] == '%'.to_int() &&
    bytes[at + 1] != '%'.to_int() {
    let mut cursor = at + 1
    while cursor < bytes.length() && !pdf_break(bytes[cursor]) {
      cursor = cursor + 1
    }
    match pdf_newline(bytes, cursor) {
      Some(next) => next
      None => at
    }
  } else {
    at
  }
}

///|
fn pdf_object(
  env : Env,
  bytes : Array[Int],
  at : Int,
  objects : @value.MapValue,
) -> (Int, @value.Cell)? raise EvalError {
  match pdf_ref_id(bytes, at) {
    None => None
    Some((key, after_id)) => {
      let mut cursor = pdf_gap(bytes, after_id)
      if !pdf_keyword(bytes, cursor, "obj") {
        return None
      }
      cursor = pdf_gap(bytes, cursor + 3)
      match pdf_value(env, bytes, cursor, objects) {
        None => None
        Some((cell, next)) => {
          cursor = pdf_gap(bytes, next)
          if pdf_keyword(bytes, cursor, "endobj") {
            if pdf_is_objstm(env, cell) {
              pdf_import_objstm(env, cell, objects)
            } else {
              objects.put(key, cell)
            }
            Some((cursor + 6, cell))
          } else {
            None
          }
        }
      }
    }
  }
}

///|
/// A linearized file stores the real trailer at the byte offset `T` of the
/// first object. The dictionary there replaces the trailer keyword.
fn pdf_linearized(
  env : Env,
  bytes : Array[Int],
  objects : @value.MapValue,
  refs : @value.Series,
  trailer : @value.Cell,
) -> @value.Cell raise EvalError {
  if objects.length() == 0 {
    return trailer
  }
  match objects.value(0) {
    Some(@value.Map(map)) =>
      if pdf_truthy(pdf_map_field(map, "linearized")) {
        let mut current = trailer
        if objects.length() >= 2 {
          match objects.value(1) {
            Some(@value.Object(frame)) =>
              if pdf_spec_is(env, frame, "xref") {
                current = pdf_xref_stream(env, frame, refs)
              }
            _ => ()
          }
        }
        match pdf_map_field(map, "t") {
          Some(@value.Integer(offset)) =>
            match
              pdf_object(env, bytes, pdf_gap(bytes, offset.to_int()), objects) {
              Some((_, cell)) => cell
              None => current
            }
          _ => current
        }
      } else {
        trailer
      }
    _ => trailer
  }
}

///|
/// An XRef stream's `W` array is three field widths. Each entry becomes
/// `[id×field3 type field2]`, and the stream bytes are consumed.
fn pdf_xref_stream(
  env : Env,
  frame : @value.Frame,
  refs : @value.Series,
) -> @value.Cell raise EvalError {
  let spec = match frame_field(env, frame, "spec") {
    Some(@value.Map(map)) => map
    _ => return @value.Cell::None
  }
  let widths = match pdf_map_field(spec, "w") {
    Some(cell) =>
      match pdf_int_block(cell) {
        Some(values) =>
          if values.length() >= 3 {
            values
          } else {
            return pdf_xref_trailer(env, spec)
          }
        None => return pdf_xref_trailer(env, spec)
      }
    None => return pdf_xref_trailer(env, spec)
  }
  let mut data = pdf_flate_data(env, frame, spec)
  let ranges = match pdf_map_field(spec, "index") {
    Some(cell) =>
      match pdf_int_block(cell) {
        Some(values) => values
        None => []
      }
    None =>
      match pdf_map_field(spec, "size") {
        Some(@value.Integer(size)) => [0L, size]
        _ => []
      }
  }
  let mut range_at = 0
  while range_at + 1 < ranges.length() {
    let mut id = ranges[range_at]
    let mut count = ranges[range_at + 1]
    while count > 0L {
      if data.length() <
        widths[0].to_int() + widths[1].to_int() + widths[2].to_int() {
        count = 0L
      } else {
        let kind = pdf_be(data, 0, widths[0].to_int())
        data = pdf_drop(data, widths[0].to_int())
        let second = pdf_be(data, 0, widths[1].to_int())
        data = pdf_drop(data, widths[1].to_int())
        let third = pdf_be(data, 0, widths[2].to_int())
        data = pdf_drop(data, widths[2].to_int())
        let paired = if kind == 2L { 0L } else { third }
        refs.push_item(@value.Pair(id, paired)) |> ignore
        refs.push_item(@value.Integer(kind)) |> ignore
        refs.push_item(@value.Integer(second)) |> ignore
        id = id + 1L
        count = count - 1L
      }
    }
    range_at = range_at + 2
  }
  put_field(env, frame, "data", binary_cell(data))
  pdf_xref_trailer(env, spec)
}

///|

///|
/// `FlateDecode` drops the two zlib header bytes and inflates the rest.
/// The filter is cleared and `Length` becomes the inflated size. A bad
/// stream is left as it was.
fn pdf_flate_data(
  env : Env,
  frame : @value.Frame,
  spec : @value.MapValue,
) -> Array[Int] {
  let stored = match frame_field(env, frame, "data") {
    Some(@value.Seq(series, index)) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => []
  }
  match pdf_map_field(spec, "filter") {
    Some(@value.Sym(_, lexeme)) =>
      if lexeme.spelling().to_lower() == "flatedecode" && stored.length() >= 2 {
        let body = pdf_drop(stored, 2)
        let plain = c_zlib_decompress(latin_text(body), body.length(), -15)
        if c_zlib_code() == 0 {
          let inflated = codes_of(plain)
          spec.put(pdf_name_cell(env, "Filter"), @value.Cell::None)
          spec.put(
            pdf_name_cell(env, "Length"),
            @value.Integer(inflated.length().to_int64()),
          )
          inflated
        } else {
          stored
        }
      } else {
        stored
      }
    _ => stored
  }
}

///|
fn pdf_xref_trailer(env : Env, spec : @value.MapValue) -> @value.Cell {
  let trailer = @value.MapValue::make()
  trailer.put(
    pdf_name_cell(env, "Size"),
    pdf_or_none(pdf_map_field(spec, "size")),
  )
  trailer.put(
    pdf_name_cell(env, "Root"),
    pdf_or_none(pdf_map_field(spec, "root")),
  )
  trailer.put(
    pdf_name_cell(env, "Info"),
    pdf_or_none(pdf_map_field(spec, "info")),
  )
  trailer.put(pdf_name_cell(env, "ID"), pdf_or_none(pdf_map_field(spec, "id")))
  @value.Map(trailer)
}

///|
fn pdf_or_none(cell : @value.Cell?) -> @value.Cell {
  match cell {
    Some(value) => value
    None => @value.Cell::None
  }
}

///|
fn pdf_is_objstm(env : Env, cell : @value.Cell) -> Bool {
  match cell {
    @value.Object(frame) => pdf_spec_is(env, frame, "objstm")
    _ => false
  }
}

///|
/// The stream itself is not kept. Each `id offset` pair names one value
/// stored after the byte `First`.
fn pdf_import_objstm(
  env : Env,
  cell : @value.Cell,
  objects : @value.MapValue,
) -> Unit raise EvalError {
  let frame = match cell {
    @value.Object(frame) => frame
    _ => return
  }
  let spec = match frame_field(env, frame, "spec") {
    Some(@value.Map(map)) => map
    _ => return
  }
  let data = pdf_flate_data(env, frame, spec)
  let first = match pdf_map_field(spec, "first") {
    Some(@value.Integer(n)) if n >= 0L => n.to_int()
    _ => return
  }
  if first > data.length() {
    return
  }
  let numbers = match pdf_int_block(load(env, pdf_latin(data, 0, first))) {
    Some(values) => values
    None => return
  }
  let mut index = 0
  while index + 1 < numbers.length() {
    let at = first + numbers[index + 1].to_int()
    if at >= 0 && at <= data.length() {
      match pdf_value(env, data, at, objects) {
        Some((inner, _)) => objects.put(@value.Pair(numbers[index], 0L), inner)
        None => ()
      }
    }
    index = index + 2
  }
}

///|
fn pdf_spec_is(env : Env, frame : @value.Frame, name : String) -> Bool {
  match frame_field(env, frame, "spec") {
    Some(@value.Map(map)) =>
      match pdf_map_field(map, "type") {
        Some(@value.Sym(_, lexeme)) => lexeme.spelling().to_lower() == name
        _ => false
      }
    _ => false
  }
}

///|
fn pdf_int_block(cell : @value.Cell) -> Array[Int64]? {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let values : Array[Int64] = []
      let mut cursor = index
      let mut ok = true
      while ok && cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Integer(number)) => values.push(number)
          _ => ok = false
        }
        cursor = cursor + 1
      }
      if ok {
        Some(values)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn pdf_be(bytes : Array[Int], at : Int, width : Int) -> Int64 {
  let mut value = 0L
  let mut index = 0
  while index < width && at + index < bytes.length() {
    value = value * 256L + bytes[at + index].to_int64()
    index = index + 1
  }
  value
}

///|
fn pdf_drop(bytes : Array[Int], width : Int) -> Array[Int] {
  let rest : Array[Int] = []
  let mut index = width
  while index < bytes.length() {
    rest.push(bytes[index])
    index = index + 1
  }
  rest
}

///|
fn pdf_truthy(cell : @value.Cell?) -> Bool {
  match cell {
    Some(@value.Cell::None)
    | Some(@value.Logic(false))
    | Some(@value.Integer(0L)) => false
    Some(@value.Decimal(number)) => number != 0.0
    Some(_) => true
    None => false
  }
}

///|
fn pdf_value(
  env : Env,
  bytes : Array[Int],
  at : Int,
  objects : @value.MapValue,
) -> (@value.Cell, Int)? raise EvalError {
  if at >= bytes.length() {
    None
  } else if bytes[at] == '/'.to_int() {
    pdf_name(env, bytes, at)
  } else if pdf_digit(bytes[at]) {
    match pdf_reference(bytes, at) {
      Some(found) => Some(found)
      None => pdf_number(bytes, at)
    }
  } else if bytes[at] == '+'.to_int() || bytes[at] == '-'.to_int() {
    pdf_number(bytes, at)
  } else if pdf_keyword(bytes, at, "true") {
    Some((@value.Logic(true), at + 4))
  } else if pdf_keyword(bytes, at, "false") {
    Some((@value.Logic(false), at + 5))
  } else if pdf_keyword(bytes, at, "null") {
    Some((@value.Cell::None, at + 4))
  } else if bytes[at] == '('.to_int() {
    match pdf_date(bytes, at) {
      Some(found) => Some(found)
      None => pdf_string(bytes, at)
    }
  } else if pdf_keyword(bytes, at, "<<") {
    pdf_dict(env, bytes, at, objects)
  } else if bytes[at] == '<'.to_int() {
    pdf_hex(bytes, at)
  } else if bytes[at] == '['.to_int() {
    pdf_array(env, bytes, at, objects)
  } else {
    None
  }
}

///|
fn pdf_name(env : Env, bytes : Array[Int], at : Int) -> (@value.Cell, Int)? {
  let mut cursor = at + 1
  while cursor < bytes.length() && pdf_name_char(bytes[cursor]) {
    cursor = cursor + 1
  }
  let text = pdf_dehex(pdf_latin(bytes, at + 1, cursor))
  Some((pdf_name_cell(env, text), cursor))
}

///|
fn pdf_name_cell(env : Env, text : String) -> @value.Cell {
  if pdf_wordish(text) {
    let sym = env.symbols.intern(text)
    @value.Sym(@value.Word, @value.Lexeme::make(sym, text))
  } else {
    text_series(text)
  }
}

///|
fn pdf_wordish(text : String) -> Bool {
  let mut index = 0
  let mut ok = text.length() > 0
  for char in text {
    if index == 0 {
      ok = ok && pdf_word_start(char)
    } else if !pdf_word_more(char) {
      ok = false
    }
    index = index + 1
  }
  ok
}

///|
fn pdf_word_start(char : Char) -> Bool {
  pdf_word_more(char) && !(char >= '0' && char <= '9')
}

///|
fn pdf_word_more(char : Char) -> Bool {
  (char >= 'A' && char <= 'Z') ||
  (char >= 'a' && char <= 'z') ||
  (char >= '0' && char <= '9') ||
  char == '+' ||
  char == '-' ||
  char == '*' ||
  char == '=' ||
  char == '?' ||
  char == '!' ||
  char == '.' ||
  char == '_' ||
  char == '\'' ||
  char == '&' ||
  char == '|' ||
  char == '~'
}

///|
fn pdf_dehex(text : String) -> String {
  let buf = StringBuilder()
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  let mut index = 0
  while index < codes.length() {
    if codes[index] == '#'.to_int() &&
      index + 2 < codes.length() &&
      pdf_hex_digit(codes[index + 1]) &&
      pdf_hex_digit(codes[index + 2]) {
      let code = pdf_hex_value(codes[index + 1]) * 16 +
        pdf_hex_value(codes[index + 2])
      match code.to_char() {
        Some(char) => buf.write_char(char)
        None => ()
      }
      index = index + 3
    } else {
      match codes[index].to_char() {
        Some(char) => buf.write_char(char)
        None => ()
      }
      index = index + 1
    }
  }
  buf.to_string()
}

///|
fn pdf_reference(bytes : Array[Int], at : Int) -> (@value.Cell, Int)? {
  match pdf_uint(bytes, at) {
    None => None
    Some((first, next)) => {
      let cursor = pdf_gap(bytes, next)
      match pdf_uint(bytes, cursor) {
        None => None
        Some((second, after)) => {
          let end = pdf_gap(bytes, after)
          if end < bytes.length() &&
            bytes[end] == 'R'.to_int() &&
            !pdf_name_char(pdf_at(bytes, end + 1)) {
            Some((@value.Pair(first, second), end + 1))
          } else {
            None
          }
        }
      }
    }
  }
}

///|
fn pdf_number(bytes : Array[Int], at : Int) -> (@value.Cell, Int)? {
  let mut cursor = at
  let mut negative = false
  if cursor < bytes.length() &&
    (bytes[cursor] == '+'.to_int() || bytes[cursor] == '-'.to_int()) {
    negative = bytes[cursor] == '-'.to_int()
    cursor = cursor + 1
  }
  let mut whole = 0L
  let mut saw_digit = false
  while cursor < bytes.length() && pdf_digit(bytes[cursor]) {
    whole = whole * 10L + (bytes[cursor] - '0'.to_int()).to_int64()
    saw_digit = true
    cursor = cursor + 1
  }
  if cursor < bytes.length() && bytes[cursor] == '.'.to_int() {
    cursor = cursor + 1
    let mut fraction_int = 0L
    let mut scale = 1.0
    let mut saw_fraction = false
    while cursor < bytes.length() && pdf_digit(bytes[cursor]) {
      fraction_int = fraction_int * 10L +
        (bytes[cursor] - '0'.to_int()).to_int64()
      scale = scale * 10.0
      saw_fraction = true
      cursor = cursor + 1
    }
    let fraction = fraction_int.to_double() / scale
    if !saw_digit && !saw_fraction {
      None
    } else {
      let magnitude = whole.to_double() + fraction
      if negative {
        Some((@value.Decimal(-magnitude), cursor))
      } else {
        Some((@value.Decimal(magnitude), cursor))
      }
    }
  } else if saw_digit {
    if negative {
      Some((@value.Integer(-whole), cursor))
    } else {
      Some((@value.Integer(whole), cursor))
    }
  } else {
    None
  }
}

///|
fn pdf_string(bytes : Array[Int], at : Int) -> (@value.Cell, Int)? {
  match pdf_string_text(bytes, at) {
    Some((text, next)) => Some((text_series(text), next))
    None => None
  }
}

///|
fn pdf_string_text(bytes : Array[Int], at : Int) -> (String, Int)? {
  if at >= bytes.length() || bytes[at] != '('.to_int() {
    return None
  }
  match pdf_string_body(bytes, at + 1) {
    Some((text, next)) =>
      if next < bytes.length() && bytes[next] == ')'.to_int() {
        Some((text, next + 1))
      } else {
        None
      }
    None => None
  }
}

///|
fn pdf_string_body(bytes : Array[Int], at : Int) -> (String, Int)? {
  let buf = StringBuilder()
  let mut cursor = at
  let mut failed = false
  while cursor < bytes.length() && bytes[cursor] != ')'.to_int() && !failed {
    if bytes[cursor] == '('.to_int() {
      buf.write_char('(')
      match pdf_string_body(bytes, cursor + 1) {
        Some((inner, next)) =>
          if next < bytes.length() && bytes[next] == ')'.to_int() {
            buf.write_string(inner)
            buf.write_char(')')
            cursor = next + 1
          } else {
            failed = true
          }
        None => failed = true
      }
    } else if bytes[cursor] == '\\'.to_int() {
      match pdf_escape(bytes, cursor) {
        Some((None, next)) => cursor = next
        Some((Some(char), next)) => {
          buf.write_char(char)
          cursor = next
        }
        None => failed = true
      }
    } else {
      match bytes[cursor].to_char() {
        Some(char) => buf.write_char(char)
        None => ()
      }
      cursor = cursor + 1
    }
  }
  if failed {
    None
  } else {
    Some((buf.to_string(), cursor))
  }
}

///|
fn pdf_escape(bytes : Array[Int], at : Int) -> (Char?, Int)? {
  if at + 1 >= bytes.length() {
    return None
  }
  let code = bytes[at + 1]
  if code == 'n'.to_int() {
    Some((Some('\n'), at + 2))
  } else if code == 'r'.to_int() {
    Some((Some('\r'), at + 2))
  } else if code == 't'.to_int() {
    Some((Some('\t'), at + 2))
  } else if code == 'b'.to_int() {
    Some((Some('\u{0008}'), at + 2))
  } else if code == 'f'.to_int() {
    Some((Some('\u{000C}'), at + 2))
  } else if code == '('.to_int() ||
    code == ')'.to_int() ||
    code == '\\'.to_int() {
    match code.to_char() {
      Some(char) => Some((Some(char), at + 2))
      None => None
    }
  } else if pdf_break(code) {
    match pdf_newline(bytes, at + 1) {
      Some(next) => Some((None, next))
      None => None
    }
  } else if pdf_octal(code) {
    let mut cursor = at + 1
    let mut count = 0
    let mut value = 0
    while cursor < bytes.length() && count < 3 && pdf_octal(bytes[cursor]) {
      value = value * 8 + (bytes[cursor] - '0'.to_int())
      cursor = cursor + 1
      count = count + 1
    }
    if count >= 2 {
      match value.to_char() {
        Some(char) => Some((Some(char), cursor))
        None => None
      }
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn pdf_date(bytes : Array[Int], at : Int) -> (@value.Cell, Int)? {
  if !pdf_keyword(bytes, at, "(D:") {
    return None
  }
  let mut cursor = at + 3
  match pdf_fixed(bytes, cursor, 4) {
    None => None
    Some((year, next)) => {
      cursor = next
      let mut month = 1
      let mut day = 1
      let mut hour = 0
      let mut minute = 0
      let mut second = 0
      match pdf_fixed(bytes, cursor, 2) {
        Some((value, next)) => {
          month = value
          cursor = next
          match pdf_fixed(bytes, cursor, 2) {
            Some((value, next)) => {
              day = value
              cursor = next
              match pdf_fixed(bytes, cursor, 2) {
                Some((value, next)) => {
                  hour = value
                  cursor = next
                  match pdf_fixed(bytes, cursor, 2) {
                    Some((value, next)) => {
                      minute = value
                      cursor = next
                      match pdf_fixed(bytes, cursor, 2) {
                        Some((value, next)) => {
                          second = value
                          cursor = next
                        }
                        None => ()
                      }
                    }
                    None => ()
                  }
                }
                None => ()
              }
            }
            None => ()
          }
        }
        None => ()
      }
      let seconds = hour.to_double() * 3600.0 +
        minute.to_double() * 60.0 +
        second.to_double()
      let mut zone : Int? = None
      if cursor < bytes.length() && bytes[cursor] == 'Z'.to_int() {
        cursor = cursor + 1
      } else if cursor < bytes.length() &&
        (bytes[cursor] == '+'.to_int() || bytes[cursor] == '-'.to_int()) {
        let sign = if bytes[cursor] == '-'.to_int() { -1 } else { 1 }
        cursor = cursor + 1
        match pdf_fixed(bytes, cursor, 2) {
          Some((zone_hour, next)) =>
            if next < bytes.length() && bytes[next] == '\''.to_int() {
              match pdf_fixed(bytes, next + 1, 2) {
                Some((zone_minute, znext)) =>
                  if znext < bytes.length() && bytes[znext] == '\''.to_int() {
                    zone = Some(sign * (zone_hour * 60 + zone_minute))
                    cursor = znext + 1
                  }
                None => ()
              }
            }
          None => ()
        }
      }
      if cursor < bytes.length() && bytes[cursor] == ')'.to_int() {
        Some(
          (
            @value.Date(
              @value.DateValue::make(year, month, day, Some(seconds), zone),
            ),
            cursor + 1,
          ),
        )
      } else {
        None
      }
    }
  }
}

///|
fn pdf_dict(
  env : Env,
  bytes : Array[Int],
  at : Int,
  objects : @value.MapValue,
) -> (@value.Cell, Int)? raise EvalError {
  let map = @value.MapValue::make()
  let mut cursor = pdf_gap(bytes, at + 2)
  let mut failed = false
  while cursor < bytes.length() && !pdf_keyword(bytes, cursor, ">>") && !failed {
    match pdf_name(env, bytes, cursor) {
      None => failed = true
      Some((key, next)) => {
        cursor = pdf_gap(bytes, next)
        match pdf_value(env, bytes, cursor, objects) {
          None => failed = true
          Some((cell, next)) => {
            map.put(key, cell)
            cursor = pdf_gap(bytes, next)
          }
        }
      }
    }
  }
  if failed || !pdf_keyword(bytes, cursor, ">>") {
    None
  } else {
    cursor = cursor + 2
    match pdf_stream(bytes, cursor, pdf_length(map)) {
      Some((data, next)) => {
        let frame = @value.Frame::new()
        put_field(env, frame, "spec", @value.Map(map))
        put_field(env, frame, "data", binary_cell(data))
        Some((@value.Object(frame), next))
      }
      None => Some((@value.Map(map), cursor))
    }
  }
}

///|
fn pdf_length(map : @value.MapValue) -> Int? {
  let mut found : Int? = None
  let mut index = 0
  while found is None && index < map.length() {
    match (map.key(index), map.value(index)) {
      (Some(@value.Sym(_, lexeme)), Some(@value.Integer(number))) if lexeme
        .spelling()
        .to_lower() ==
        "length" =>
        if number >= 0L && number <= 2147483647L {
          found = Some(number.to_int())
        }
      _ => ()
    }
    index = index + 1
  }
  found
}

///|
fn pdf_stream(
  bytes : Array[Int],
  at : Int,
  length : Int?,
) -> (Array[Int], Int)? {
  let cursor = pdf_gap(bytes, at)
  if !pdf_keyword(bytes, cursor, "stream") {
    return None
  }
  match pdf_newline(bytes, cursor + 6) {
    None => None
    Some(start) =>
      match length {
        Some(size) =>
          match pdf_stream_exact(bytes, start, size) {
            Some(found) => Some(found)
            None => pdf_stream_until(bytes, start)
          }
        None => pdf_stream_until(bytes, start)
      }
  }
}

///|
fn pdf_stream_exact(
  bytes : Array[Int],
  at : Int,
  size : Int,
) -> (Array[Int], Int)? {
  if at + size > bytes.length() {
    return None
  }
  match pdf_newline(bytes, at + size) {
    None => None
    Some(next) =>
      if pdf_keyword(bytes, next, "endstream") {
        match pdf_newline(bytes, next + 9) {
          Some(end) => Some((pdf_slice(bytes, at, size), end))
          None => Some((pdf_slice(bytes, at, size), next + 9))
        }
      } else {
        None
      }
  }
}

///|
fn pdf_stream_until(bytes : Array[Int], at : Int) -> (Array[Int], Int)? {
  let mark = "\nendstream"
  let mut cursor = at
  let mut found = false
  while cursor < bytes.length() && !found {
    if pdf_keyword(bytes, cursor, mark) {
      found = true
    } else {
      cursor = cursor + 1
    }
  }
  if found {
    let data = pdf_slice(bytes, at, cursor - at)
    let mut end = cursor + mark.length()
    match pdf_newline(bytes, end) {
      Some(next) => end = next
      None => ()
    }
    Some((data, end))
  } else {
    None
  }
}

///|
fn pdf_array(
  env : Env,
  bytes : Array[Int],
  at : Int,
  objects : @value.MapValue,
) -> (@value.Cell, Int)? raise EvalError {
  let block = @value.Series::block()
  let mut cursor = pdf_gap(bytes, at + 1)
  let mut failed = false
  while cursor < bytes.length() && bytes[cursor] != ']'.to_int() && !failed {
    match pdf_value(env, bytes, cursor, objects) {
      None => failed = true
      Some((cell, next)) => {
        block.push_item(cell) |> ignore
        cursor = pdf_gap(bytes, next)
      }
    }
  }
  if failed || cursor >= bytes.length() || bytes[cursor] != ']'.to_int() {
    None
  } else {
    Some((@value.Seq(block, 0), cursor + 1))
  }
}

///|
fn pdf_hex(bytes : Array[Int], at : Int) -> (@value.Cell, Int)? {
  let mut cursor = at + 1
  let digits : Array[Int] = []
  let mut failed = false
  while cursor < bytes.length() && bytes[cursor] != '>'.to_int() && !failed {
    if pdf_hex_digit(bytes[cursor]) {
      digits.push(pdf_hex_value(bytes[cursor]))
      cursor = cursor + 1
    } else if pdf_space(bytes[cursor]) {
      cursor = cursor + 1
    } else {
      failed = true
    }
  }
  if failed || cursor >= bytes.length() {
    None
  } else {
    if digits.length() % 2 == 1 {
      digits.push(0)
    }
    let bytes_out : Array[Int] = []
    let mut index = 0
    while index < digits.length() {
      bytes_out.push(digits[index] * 16 + digits[index + 1])
      index = index + 2
    }
    Some((binary_cell(bytes_out), cursor + 1))
  }
}

///|
fn pdf_xref(bytes : Array[Int], at : Int, refs : @value.Series) -> Int? {
  match pdf_newline(bytes, at + 4) {
    None => None
    Some(start) => {
      let mut cursor = start
      let mut any = false
      let mut more = true
      while more {
        match pdf_subsection(bytes, cursor, refs) {
          Some(next) => {
            cursor = next
            any = true
            let ahead = pdf_gap(bytes, cursor)
            if !pdf_digit(pdf_at(bytes, ahead)) {
              more = false
            }
          }
          None => more = false
        }
      }
      if any {
        Some(cursor)
      } else {
        None
      }
    }
  }
}

///|
fn pdf_subsection(bytes : Array[Int], at : Int, refs : @value.Series) -> Int? {
  match pdf_uint(bytes, pdf_gap(bytes, at)) {
    None => None
    Some((_, next)) =>
      match pdf_uint(bytes, pdf_gap(bytes, next)) {
        None => None
        Some((count, after)) =>
          match pdf_newline(bytes, pdf_spaces(bytes, after)) {
            None => None
            Some(line) => {
              let mut cursor = line
              let mut left = count.to_int()
              let mut failed = false
              while left > 0 && !failed {
                match pdf_xref_entry(bytes, cursor, refs) {
                  Some(next) => {
                    cursor = next
                    left = left - 1
                  }
                  None => failed = true
                }
              }
              if failed {
                None
              } else {
                Some(cursor)
              }
            }
          }
      }
  }
}

///|
fn pdf_xref_entry(bytes : Array[Int], at : Int, refs : @value.Series) -> Int? {
  match pdf_fixed(bytes, at, 10) {
    None => None
    Some((offset, next)) =>
      if next < bytes.length() && bytes[next] == ' '.to_int() {
        match pdf_fixed(bytes, next + 1, 5) {
          None => None
          Some((generation, after)) =>
            if after + 1 < bytes.length() &&
              bytes[after] == ' '.to_int() &&
              (
                bytes[after + 1] == 'n'.to_int() ||
                bytes[after + 1] == 'f'.to_int()
              ) {
              refs.push_item(@value.Integer(offset.to_int64())) |> ignore
              refs.push_item(@value.Integer(generation.to_int64())) |> ignore
              refs.push_item(@value.Char(bytes[after + 1])) |> ignore
              let mut cursor = after + 2
              while cursor < bytes.length() && bytes[cursor] == ' '.to_int() {
                cursor = cursor + 1
              }
              match pdf_newline(bytes, cursor) {
                Some(end) => Some(end)
                None => None
              }
            } else {
              None
            }
        }
      } else {
        None
      }
  }
}

///|
fn pdf_tail(
  env : Env,
  bytes : Array[Int],
  at : Int,
  objects : @value.MapValue,
) -> (Int, @value.Cell?, @value.Cell?)? raise EvalError {
  let mut cursor = at
  let mut trailer : @value.Cell? = None
  if pdf_keyword(bytes, cursor, "trailer") {
    match pdf_newline(bytes, cursor + 7) {
      None => return None
      Some(next) =>
        match pdf_value(env, bytes, pdf_gap(bytes, next), objects) {
          None => return None
          Some((cell, end)) => {
            trailer = Some(cell)
            cursor = pdf_gap(bytes, end)
          }
        }
    }
  }
  if pdf_keyword(bytes, cursor, "startxref") {
    match pdf_newline(bytes, cursor + 9) {
      None => None
      Some(next) =>
        match pdf_uint(bytes, pdf_gap(bytes, next)) {
          None => None
          Some((number, end)) =>
            match pdf_newline(bytes, pdf_spaces(bytes, end)) {
              Some(done) => Some((done, trailer, Some(@value.Integer(number))))
              None => Some((end, trailer, Some(@value.Integer(number))))
            }
        }
    }
  } else {
    Some((cursor, trailer, None))
  }
}

///|
fn pdf_ref_id(bytes : Array[Int], at : Int) -> (@value.Cell, Int)? {
  match pdf_uint(bytes, pdf_gap(bytes, at)) {
    None => None
    Some((object_id, next)) =>
      match pdf_uint(bytes, pdf_gap(bytes, next)) {
        Some((generation, end)) =>
          Some((@value.Pair(object_id, generation), end))
        None => None
      }
  }
}

///|
fn pdf_uint(bytes : Array[Int], at : Int) -> (Int64, Int)? {
  if !pdf_digits_at(bytes, at) {
    None
  } else {
    let mut cursor = at
    let mut value = 0L
    while cursor < bytes.length() && pdf_digit(bytes[cursor]) {
      value = value * 10L + (bytes[cursor] - '0'.to_int()).to_int64()
      cursor = cursor + 1
    }
    Some((value, cursor))
  }
}

///|
fn pdf_fixed(bytes : Array[Int], at : Int, width : Int) -> (Int, Int)? {
  if at + width > bytes.length() {
    return None
  }
  let mut cursor = at
  let mut value = 0
  let mut count = 0
  while count < width {
    if !pdf_digit(bytes[cursor]) {
      return None
    }
    value = value * 10 + (bytes[cursor] - '0'.to_int())
    cursor = cursor + 1
    count = count + 1
  }
  Some((value, cursor))
}

///|
fn pdf_keyword(bytes : Array[Int], at : Int, word : String) -> Bool {
  let mut cursor = at
  let mut matched = true
  for char in word {
    if cursor >= bytes.length() || bytes[cursor] != char.to_int() {
      matched = false
    }
    cursor = cursor + 1
  }
  if !matched || word.length() == 0 {
    false
  } else if word == "<<" ||
    word == ">>" ||
    word == "%%EOF" ||
    word == "%PDF-" ||
    word == "(D:" {
    true
  } else {
    !pdf_name_char(pdf_at(bytes, cursor))
  }
}

///|
fn pdf_gap(bytes : Array[Int], at : Int) -> Int {
  let mut cursor = at
  while cursor < bytes.length() && pdf_space(bytes[cursor]) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn pdf_spaces(bytes : Array[Int], at : Int) -> Int {
  let mut cursor = at
  while cursor < bytes.length() &&
        (bytes[cursor] == ' '.to_int() || bytes[cursor] == '\t'.to_int()) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn pdf_newline(bytes : Array[Int], at : Int) -> Int? {
  if at >= bytes.length() {
    None
  } else if bytes[at] == '\n'.to_int() ||
    (
      bytes[at] == '\r'.to_int() &&
      !(at + 1 < bytes.length() && bytes[at + 1] == '\n'.to_int())
    ) {
    Some(at + 1)
  } else if bytes[at] == '\r'.to_int() {
    Some(at + 2)
  } else {
    None
  }
}

///|
fn pdf_slice(bytes : Array[Int], at : Int, size : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index < size && at + index < bytes.length() {
    out.push(bytes[at + index])
    index = index + 1
  }
  out
}

///|
fn pdf_latin(bytes : Array[Int], start : Int, end : Int) -> String {
  let buf = StringBuilder()
  let mut index = start
  while index < end && index < bytes.length() {
    match bytes[index].to_char() {
      Some(char) => buf.write_char(char)
      None => ()
    }
    index = index + 1
  }
  buf.to_string()
}

///|
fn pdf_at(bytes : Array[Int], at : Int) -> Int {
  if at >= 0 && at < bytes.length() {
    bytes[at]
  } else {
    -1
  }
}

///|
fn pdf_digits_at(bytes : Array[Int], at : Int) -> Bool {
  at < bytes.length() && pdf_digit(bytes[at])
}

///|
fn pdf_digit(code : Int) -> Bool {
  code >= '0'.to_int() && code <= '9'.to_int()
}

///|
fn pdf_octal(code : Int) -> Bool {
  code >= '0'.to_int() && code <= '7'.to_int()
}

///|
fn pdf_hex_digit(code : Int) -> Bool {
  pdf_digit(code) ||
  (code >= 'a'.to_int() && code <= 'f'.to_int()) ||
  (code >= 'A'.to_int() && code <= 'F'.to_int())
}

///|
fn pdf_hex_value(code : Int) -> Int {
  if code >= '0'.to_int() && code <= '9'.to_int() {
    code - '0'.to_int()
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    code - 'a'.to_int() + 10
  } else {
    code - 'A'.to_int() + 10
  }
}

///|
fn pdf_name_char(code : Int) -> Bool {
  code > 32 &&
  code != '('.to_int() &&
  code != ')'.to_int() &&
  code != '<'.to_int() &&
  code != '>'.to_int() &&
  code != '['.to_int() &&
  code != ']'.to_int() &&
  code != '{'.to_int() &&
  code != '}'.to_int() &&
  code != '/'.to_int() &&
  code != '%'.to_int()
}

///|
fn pdf_space(code : Int) -> Bool {
  code == ' '.to_int() ||
  code == '\t'.to_int() ||
  code == '\n'.to_int() ||
  code == '\r'.to_int() ||
  code == 12
}

///|
fn pdf_break(code : Int) -> Bool {
  code == '\n'.to_int() || code == '\r'.to_int()
}

///|
/// Writes a simple PDF. Objects stay in map order. The cross-reference
/// table is sorted by object number. A document with no catalog is none.
fn encode_pdf(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Object(frame) =>
      match pdf_encode_frame(env, frame) {
        Some(bytes) => binary_cell(bytes)
        None => @value.Cell::None
      }
    _ => @value.Cell::None
  }
}

///|
priv struct PdfSpot {
  id : Int64
  gen : Int64
  offset : Int
}

///|
fn pdf_encode_frame(
  env : Env,
  frame : @value.Frame,
) -> Array[Int]? raise EvalError {
  let objects = match frame_field(env, frame, "objects") {
    Some(@value.Map(map)) => map
    _ => return None
  }
  let trailer = match pdf_trailer(env, objects, frame) {
    Some(map) => map
    None => return None
  }
  let version = match pdf_version(env, frame) {
    Some(text) => text
    None => return None
  }
  let out : Array[Int] = []
  pdf_bytes(out, "%PDF-")
  pdf_bytes(out, version)
  out.push('\r'.to_int())
  out.push('%'.to_int())
  out.push(0xE2)
  out.push(0xE3)
  out.push(0xCF)
  out.push(0xD3)
  out.push('\r'.to_int())
  out.push('\n'.to_int())
  let spots : Array[PdfSpot] = []
  for index in 0..<objects.length() {
    match (objects.key(index), objects.value(index)) {
      (Some(@value.Pair(id, gen)), Some(cell)) => {
        let offset = out.length()
        pdf_bytes(out, id.to_string() + " " + gen.to_string() + " obj\r")
        pdf_emit(env, out, cell)
        pdf_bytes(out, "\rendobj\r")
        spots.push(PdfSpot::{ id, gen, offset, })
      }
      _ => ()
    }
  }
  pdf_sort_spots(spots)
  let xref_at = out.length()
  pdf_write_xref(out, spots)
  pdf_bytes(out, "trailer\r\n")
  pdf_emit(env, out, @value.Map(trailer))
  pdf_bytes(out, "\r\nstartxref\r\n")
  pdf_bytes(out, xref_at.to_string())
  pdf_bytes(out, "\r\n%%EOF\r\n")
  Some(out)
}

///|
fn pdf_trailer(
  env : Env,
  objects : @value.MapValue,
  frame : @value.Frame,
) -> @value.MapValue? {
  let trailer = @value.MapValue::make()
  match frame_field(env, frame, "trailer") {
    Some(@value.Map(map)) =>
      for index in 0..<map.length() {
        match (map.key(index), map.value(index)) {
          (Some(key), Some(value)) => trailer.put(key, value)
          _ => ()
        }
      }
    _ => ()
  }
  let rooted = match pdf_map_field(trailer, "root") {
    Some(cell) => !(cell is @value.Cell::None)
    None => false
  }
  if !rooted {
    match pdf_catalog(objects) {
      Some(key) => trailer.put(pdf_name_cell(env, "Root"), key)
      None => return None
    }
  }
  Some(trailer)
}

///|
fn pdf_catalog(objects : @value.MapValue) -> @value.Cell? {
  let mut found : @value.Cell? = None
  for index in 0..<objects.length() {
    if found is None {
      match (objects.key(index), objects.value(index)) {
        (Some(key), Some(@value.Map(map))) =>
          match pdf_map_field(map, "type") {
            Some(@value.Sym(_, lexeme)) =>
              if lexeme.spelling().to_lower() == "catalog" {
                found = Some(key)
              }
            _ => ()
          }
        _ => ()
      }
    }
  }
  found
}

///|
fn pdf_map_field(map : @value.MapValue, name : String) -> @value.Cell? {
  let mut found : @value.Cell? = None
  for index in 0..<map.length() {
    if found is None {
      match map.key(index) {
        Some(@value.Sym(_, lexeme)) =>
          if lexeme.spelling().to_lower() == name {
            found = map.value(index)
          }
        _ => ()
      }
    }
  }
  found
}

///|
fn pdf_version(env : Env, frame : @value.Frame) -> String? raise EvalError {
  let text = match frame_field(env, frame, "version") {
    Some(@value.Seq(series, index)) if series.datatype() == @value.String =>
      text_from(series, index)
    Some(@value.Decimal(number)) => @mold.form_text(@value.Decimal(number))
    None => "1.3"
    _ => return None
  }
  if pdf_version_text(text) {
    Some(text)
  } else {
    None
  }
}

///|
fn pdf_version_text(text : String) -> Bool {
  let mut dot = false
  let mut before = false
  let mut after = false
  for char in text {
    if char == '.' {
      if dot {
        return false
      }
      dot = true
    } else if char >= '0' && char <= '9' {
      if dot {
        after = true
      } else {
        before = true
      }
    } else {
      return false
    }
  }
  dot && before && after
}

///|
fn pdf_emit(
  env : Env,
  out : Array[Int],
  value : @value.Cell,
) -> Unit raise EvalError {
  match value {
    @value.Sym(_, lexeme) => {
      out.push('/'.to_int())
      pdf_bytes(out, lexeme.spelling())
    }
    @value.Pair(id, gen) => {
      pdf_indent(out)
      pdf_bytes(out, id.to_string() + " " + gen.to_string() + " R")
    }
    @value.Integer(number) => {
      pdf_indent(out)
      pdf_bytes(out, number.to_string())
    }
    @value.Decimal(number) => {
      pdf_indent(out)
      pdf_bytes(out, @mold.form_text(@value.Decimal(number)))
    }
    @value.Logic(flag) => {
      pdf_indent(out)
      pdf_bytes(out, if flag { "true" } else { "false" })
    }
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      out.push('['.to_int())
      for cursor in index..<series.length() {
        match series.item(cursor) {
          Some(item) => pdf_emit(env, out, item)
          None => ()
        }
      }
      out.push(']'.to_int())
    }
    @value.Seq(series, index) if series.datatype() == @value.String =>
      pdf_emit_string(out, text_from(series, index))
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      pdf_emit_hex(out, bytes_from(series, index))
    @value.Map(map) => pdf_emit_map(env, out, map)
    @value.Object(frame) => pdf_emit_stream(env, out, frame)
    _ => ()
  }
}

///|
fn pdf_emit_map(
  env : Env,
  out : Array[Int],
  map : @value.MapValue,
) -> Unit raise EvalError {
  out.push('<'.to_int())
  out.push('<'.to_int())
  for index in 0..<map.length() {
    match (map.key(index), map.value(index)) {
      (Some(@value.Sym(_, lexeme)), Some(value)) =>
        if !(value is @value.Cell::None) {
          out.push('/'.to_int())
          pdf_bytes(out, lexeme.spelling())
          pdf_emit(env, out, value)
        }
      _ => ()
    }
  }
  out.push('>'.to_int())
  out.push('>'.to_int())
}

///|
fn pdf_emit_stream(
  env : Env,
  out : Array[Int],
  frame : @value.Frame,
) -> Unit raise EvalError {
  let data = match frame_field(env, frame, "data") {
    Some(@value.Seq(series, index)) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => []
  }
  out.push('<'.to_int())
  out.push('<'.to_int())
  let mut saw = false
  match frame_field(env, frame, "spec") {
    Some(@value.Map(map)) =>
      for index in 0..<map.length() {
        match (map.key(index), map.value(index)) {
          (Some(@value.Sym(_, lexeme)), Some(value)) =>
            if lexeme.spelling().to_lower() == "length" {
              saw = true
              pdf_bytes(out, "/Length")
              pdf_indent(out)
              pdf_bytes(out, data.length().to_string())
            } else if !(value is @value.Cell::None) {
              out.push('/'.to_int())
              pdf_bytes(out, lexeme.spelling())
              pdf_emit(env, out, value)
            }
          _ => ()
        }
      }
    _ => ()
  }
  if !saw {
    pdf_bytes(out, "/Length")
    pdf_indent(out)
    pdf_bytes(out, data.length().to_string())
  }
  out.push('>'.to_int())
  out.push('>'.to_int())
  pdf_bytes(out, "stream\r\n")
  for byte in data {
    out.push(byte)
  }
  pdf_bytes(out, "\r\nendstream")
}

///|
fn pdf_emit_string(out : Array[Int], text : String) -> Unit {
  out.push('('.to_int())
  for char in text {
    if char == '\n' {
      pdf_bytes(out, "\\n")
    } else if char == '\r' {
      pdf_bytes(out, "\\r")
    } else if char == '\t' {
      pdf_bytes(out, "\\t")
    } else if char == '\u{0008}' {
      pdf_bytes(out, "\\b")
    } else if char == '\u{000C}' {
      pdf_bytes(out, "\\f")
    } else if char == '(' || char == ')' || char == '\\' {
      out.push('\\'.to_int())
      out.push(char.to_int())
    } else {
      out.push(char.to_int())
    }
  }
  out.push(')'.to_int())
}

///|
fn pdf_emit_hex(out : Array[Int], bytes : Array[Int]) -> Unit {
  out.push('<'.to_int())
  for byte in bytes {
    pdf_bytes(out, pdf_hex_byte(byte))
  }
  out.push('>'.to_int())
}

///|
fn pdf_hex_byte(byte : Int) -> String {
  let digits = "0123456789ABCDEF"
  let high = byte / 16
  let low = byte % 16
  let mut text = ""
  let mut index = 0
  for char in digits {
    if index == high || index == low {
      if index == high {
        text = text + char.to_string()
      }
      if index == low && high != low {
        text = text + char.to_string()
      } else if index == low && high == low && text.length() == 1 {
        text = text + char.to_string()
      }
    }
    index = index + 1
  }
  if text.length() == 1 {
    text = text + text
  }
  text
}

///|
fn pdf_indent(out : Array[Int]) -> Unit {
  let last = if out.length() == 0 { -1 } else { out[out.length() - 1] }
  if last != ' '.to_int() && last != '['.to_int() {
    out.push(' '.to_int())
  }
}

///|
fn pdf_write_xref(out : Array[Int], spots : Array[PdfSpot]) -> Unit {
  let end_id = pdf_xref_end(spots, 0, 0L)
  pdf_bytes(out, "xref\r\n0 " + (end_id + 1L).to_string() + "\r\n")
  pdf_bytes(out, "0000000000 65535 f\r\n")
  let mut index = 0
  let mut cursor = 0L
  while cursor < end_id && index < spots.length() {
    pdf_xref_use(out, spots[index])
    index = index + 1
    cursor = cursor + 1L
  }
  while index < spots.length() {
    let mut id = spots[index].id
    let far = pdf_xref_end(spots, index, id)
    id = id - 1L
    pdf_bytes(
      out,
      (id + 1L).to_string() + " " + (far - id).to_string() + "\r\n",
    )
    while id < far && index < spots.length() {
      pdf_xref_use(out, spots[index])
      index = index + 1
      id = id + 1L
    }
  }
}

///|
fn pdf_xref_use(out : Array[Int], spot : PdfSpot) -> Unit {
  pdf_bytes(
    out,
    pdf_pad(spot.offset, 10) + " " + pdf_pad(spot.gen.to_int(), 5) + " n\r\n",
  )
}

///|
fn pdf_xref_end(spots : Array[PdfSpot], index : Int, start : Int64) -> Int64 {
  let mut end = start
  let mut cursor = index
  while cursor < spots.length() {
    let id = spots[cursor].id
    if id - end <= 1L {
      end = id
      cursor = cursor + 1
    } else {
      break
    }
  }
  end
}

///|
fn pdf_sort_spots(spots : Array[PdfSpot]) -> Unit {
  let mut index = 1
  while index < spots.length() {
    let mut cursor = index
    while cursor > 0 && pdf_spot_before(spots[cursor], spots[cursor - 1]) {
      let item = spots[cursor]
      spots[cursor] = spots[cursor - 1]
      spots[cursor - 1] = item
      cursor = cursor - 1
    }
    index = index + 1
  }
}

///|
fn pdf_spot_before(left : PdfSpot, right : PdfSpot) -> Bool {
  if left.id != right.id {
    left.id < right.id
  } else {
    left.gen < right.gen
  }
}

///|
fn pdf_pad(number : Int, width : Int) -> String {
  let text = number.to_string()
  let mut padded = ""
  let mut size = text.length()
  while size < width {
    padded = padded + "0"
    size = size + 1
  }
  padded + text
}

///|
fn pdf_bytes(out : Array[Int], text : String) -> Unit {
  for char in text {
    out.push(char.to_int())
  }
}
