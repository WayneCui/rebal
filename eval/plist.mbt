///|
/// XML property lists, as in codec-plist.reb. A dict becomes a map. A key
/// becomes a word when the text is a word. A bad document is none.
fn decode_plist(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      text_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      qp_text(bytes_from(series, index))
    _ => raise EvalError::Cannot("decode")
  }
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  plist_document(env, codes) catch {
    _ => @value.Cell::None
  }
}

///|
fn plist_document(env : Env, codes : Array[Int]) -> @value.Cell raise EvalError {
  let mut cursor = plist_body(codes)
  let (map, after) = plist_dict(env, codes, cursor)
  cursor = plist_gap(codes, after)
  if !xml_starts(codes, cursor, "</plist>") {
    raise EvalError::Cannot("decode")
  }
  map
}

///|
fn plist_body(codes : Array[Int]) -> Int raise EvalError {
  let mut cursor = 0
  let mut found = false
  while cursor < codes.length() && !found {
    if xml_starts(codes, cursor, "<plist ") {
      found = true
    } else {
      cursor = cursor + 1
    }
  }
  if !found {
    raise EvalError::Cannot("decode")
  }
  cursor = cursor + 7
  while cursor < codes.length() && codes[cursor] != '>'.to_int() {
    cursor = cursor + 1
  }
  if cursor >= codes.length() {
    raise EvalError::Cannot("decode")
  }
  cursor + 1
}

///|
fn plist_dict(
  env : Env,
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int) raise EvalError {
  let mut cursor = plist_gap(codes, at)
  if !xml_starts(codes, cursor, "<dict>") {
    raise EvalError::Cannot("decode")
  }
  cursor = cursor + 6
  let map = @value.MapValue::make()
  let mut reading = true
  while reading {
    cursor = plist_gap(codes, cursor)
    if xml_starts(codes, cursor, "</dict>") {
      reading = false
    } else {
      let (name, named) = plist_tag(codes, cursor, "<key>", "</key>")
      let (cell, after) = plist_value(env, codes, named)
      map.put(plist_key(env, name), cell)
      cursor = after
    }
  }
  (@value.Map(map), cursor + 7)
}

///|
fn plist_array(
  env : Env,
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int) raise EvalError {
  let mut cursor = at + 7
  let block = @value.Series::block()
  let mut reading = true
  while reading {
    cursor = plist_gap(codes, cursor)
    if xml_starts(codes, cursor, "</array>") {
      reading = false
    } else {
      let (cell, after) = plist_value(env, codes, cursor)
      block.push_item(cell) |> ignore
      cursor = after
    }
  }
  (@value.Seq(block, 0), cursor + 8)
}

///|
fn plist_value(
  env : Env,
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int) raise EvalError {
  let cursor = plist_gap(codes, at)
  if xml_starts(codes, cursor, "<string>") {
    let (text, after) = plist_tag(codes, cursor, "<string>", "</string>")
    (text_series(text), after)
  } else if xml_starts(codes, cursor, "<integer>") {
    let (text, after) = plist_tag(codes, cursor, "<integer>", "</integer>")
    (plist_integer(text), after)
  } else if xml_starts(codes, cursor, "<real>") {
    let (text, after) = plist_tag(codes, cursor, "<real>", "</real>")
    (plist_real(text), after)
  } else if xml_starts(codes, cursor, "<date>") {
    let (text, after) = plist_tag(codes, cursor, "<date>", "</date>")
    (plist_date(text), after)
  } else if xml_starts(codes, cursor, "<data>") {
    let (text, after) = plist_tag(codes, cursor, "<data>", "</data>")
    (binary_cell(decode_base64(text)), after)
  } else if xml_starts(codes, cursor, "<true/>") {
    (@value.Logic(true), cursor + 7)
  } else if xml_starts(codes, cursor, "<false/>") {
    (@value.Logic(false), cursor + 8)
  } else if xml_starts(codes, cursor, "<array>") {
    plist_array(env, codes, cursor)
  } else if xml_starts(codes, cursor, "<dict>") {
    plist_dict(env, codes, cursor)
  } else {
    raise EvalError::Cannot("decode")
  }
}

///|
fn plist_tag(
  codes : Array[Int],
  at : Int,
  open : String,
  close : String,
) -> (String, Int) raise EvalError {
  if !xml_starts(codes, at, open) {
    raise EvalError::Cannot("decode")
  }
  let start = xml_skip(codes, at + plist_width(open))
  let end = xml_find(codes, start, close)
  (xml_slice(codes, start, end - plist_width(close)), end)
}

///|
fn plist_key(env : Env, name : String) -> @value.Cell {
  if json_word(name) {
    xml_word(env, name)
  } else {
    text_series(name)
  }
}

///|
fn plist_integer(text : String) -> @value.Cell raise EvalError {
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  if codes.length() == 0 {
    raise EvalError::Cannot("decode")
  }
  let mut index = 0
  let mut negative = false
  if codes[0] == '-'.to_int() {
    negative = true
    index = 1
  }
  if index >= codes.length() {
    raise EvalError::Cannot("decode")
  }
  let mut value = 0L
  while index < codes.length() {
    let code = codes[index]
    if code < '0'.to_int() || code > '9'.to_int() {
      raise EvalError::Cannot("decode")
    }
    value = value * 10L + (code - '0'.to_int()).to_int64()
    index = index + 1
  }
  if negative {
    value = 0L - value
  }
  @value.Integer(value)
}

///|
fn plist_real(text : String) -> @value.Cell raise EvalError {
  let mut negative = false
  let mut dotted = false
  let mut seen = false
  let mut value = 0.0
  let mut scale = 1.0
  let mut started = false
  for char in text {
    if char == '-' && !started {
      negative = true
      started = true
    } else if char == '.' && !dotted {
      dotted = true
      started = true
    } else if char >= '0' && char <= '9' {
      let digit = (char.to_int() - '0'.to_int()).to_double()
      if dotted {
        scale = scale * 10.0
        value = value + digit / scale
      } else {
        value = value * 10.0 + digit
      }
      seen = true
      started = true
    } else {
      raise EvalError::Cannot("decode")
    }
  }
  if !seen {
    raise EvalError::Cannot("decode")
  }
  if negative {
    value = 0.0 - value
  }
  @value.Decimal(value)
}

///|
fn plist_date(text : String) -> @value.Cell raise EvalError {
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  if codes.length() < 10 || codes[4] != '-'.to_int() || codes[7] != '-'.to_int() {
    raise EvalError::Cannot("decode")
  }
  let year = plist_digits(codes, 0, 4)
  let month = plist_digits(codes, 5, 2)
  let day = plist_digits(codes, 8, 2)
  if !@value.valid_date(year, month, day) {
    raise EvalError::Cannot("decode")
  }
  if codes.length() == 10 {
    return @value.Date(@value.DateValue::make(year, month, day, None, None))
  }
  if codes.length() < 19 ||
    (codes[10] != 'T'.to_int() && codes[10] != '/'.to_int()) ||
    codes[13] != ':'.to_int() ||
    codes[16] != ':'.to_int() {
    raise EvalError::Cannot("decode")
  }
  let hour = plist_digits(codes, 11, 2)
  let minute = plist_digits(codes, 14, 2)
  let second = plist_digits(codes, 17, 2)
  if hour > 23 || minute > 59 || second > 59 {
    raise EvalError::Cannot("decode")
  }
  let seconds = (hour * 3600 + minute * 60 + second).to_double()
  if codes.length() == 20 && codes[19] == 'Z'.to_int() {
    ()
  } else if codes.length() != 19 {
    raise EvalError::Cannot("decode")
  }
  @value.Date(@value.DateValue::make(year, month, day, Some(seconds), None))
}

///|
fn plist_digits(
  codes : Array[Int],
  at : Int,
  width : Int,
) -> Int raise EvalError {
  let mut value = 0
  for index in at..<(at + width) {
    let code = codes[index]
    if code < '0'.to_int() || code > '9'.to_int() {
      raise EvalError::Cannot("decode")
    }
    value = value * 10 + code - '0'.to_int()
  }
  value
}

///|
fn plist_gap(codes : Array[Int], at : Int) -> Int raise EvalError {
  let mut cursor = at
  let mut scanning = true
  while scanning {
    cursor = xml_skip(codes, cursor)
    if xml_starts(codes, cursor, "<!--") {
      cursor = xml_find(codes, cursor + 4, "-->")
    } else {
      scanning = false
    }
  }
  cursor
}

///|
fn plist_width(text : String) -> Int {
  let mut width = 0
  for char in text {
    let _ = char
    width = width + 1
  }
  width
}
