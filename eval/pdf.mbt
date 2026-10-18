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
      let mut start : @value.Cell = @value.Cell::None
      let mut failed = false
      let mut reading = true
      while reading && !failed {
        at = pdf_gap(bytes, at)
        match pdf_object(env, bytes, at, objects) {
          Some(next) => at = next
          None => reading = false
        }
      }
      let mut xref = true
      while xref && !failed {
        at = pdf_gap(bytes, at)
        if pdf_keyword(bytes, at, "xref") {
          match pdf_xref(bytes, at, refs) {
            Some(next) => at = next
            None => {
              failed = true
              xref = false
            }
          }
        } else {
          xref = false
        }
      }
      if !failed {
        at = pdf_gap(bytes, at)
        match pdf_tail(env, bytes, at, objects) {
          Some((next, found_trailer, found_start)) => {
            at = next
            match found_trailer {
              Some(cell) => trailer = cell
              None => ()
            }
            match found_start {
              Some(cell) => start = cell
              None => ()
            }
          }
          None => failed = true
        }
      }
      at = pdf_gap(bytes, at)
      if failed || !pdf_keyword(bytes, at, "%%EOF") {
        None
      } else {
        let frame = @value.Frame::new()
        put_field(env, frame, "version", text_series(version))
        put_field(
          env,
          frame,
          "file-size",
          @value.Integer(bytes.length().to_int64()),
        )
        put_field(env, frame, "trailer", trailer)
        put_field(env, frame, "objects", @value.Map(objects))
        put_field(env, frame, "referencies", @value.Seq(refs, 0))
        put_field(env, frame, "startxref", start)
        Some(@value.Object(frame))
      }
    }
  }
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
) -> Int? raise EvalError {
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
            objects.put(key, cell)
            Some(cursor + 6)
          } else {
            None
          }
        }
      }
    }
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
