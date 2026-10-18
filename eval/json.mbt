///|
/// JSON values, as in codec-json.reb. An object becomes a map. A key becomes
/// a word when the text is a word and not a number.
fn decode_json(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
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
  let (cell, next) = json_value(env, codes, json_skip(codes, 0))
  if json_skip(codes, next) != codes.length() {
    raise EvalError::Cannot("decode")
  }
  cell
}

///|
fn json_value(
  env : Env,
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int) raise EvalError {
  if at >= codes.length() {
    raise EvalError::Cannot("decode")
  } else if json_literal(codes, at, "true") {
    (@value.Logic(true), at + 4)
  } else if json_literal(codes, at, "false") {
    (@value.Logic(false), at + 5)
  } else if json_literal(codes, at, "null") {
    (@value.None, at + 4)
  } else if codes[at] == '{'.to_int() {
    json_object(env, codes, at + 1)
  } else if codes[at] == '['.to_int() {
    json_array(env, codes, at + 1)
  } else if codes[at] == '"'.to_int() {
    let (text, next) = json_string(codes, at + 1)
    (text_series(text), next)
  } else {
    match json_number(codes, at) {
      Some(parsed) => parsed
      None => raise EvalError::Cannot("decode")
    }
  }
}

///|
fn json_object(
  env : Env,
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int) raise EvalError {
  let map = @value.MapValue::make()
  let mut cursor = json_skip(codes, at)
  if cursor < codes.length() && codes[cursor] == '}'.to_int() {
    return (@value.Map(map), cursor + 1)
  }
  while cursor < codes.length() {
    if codes[cursor] != '"'.to_int() {
      raise EvalError::Cannot("decode")
    }
    let (name, after_name) = json_string(codes, cursor + 1)
    cursor = json_skip(codes, after_name)
    if cursor >= codes.length() || codes[cursor] != ':'.to_int() {
      raise EvalError::Cannot("decode")
    }
    let (value, after_value) = json_value(
      env,
      codes,
      json_skip(codes, cursor + 1),
    )
    map.put(json_key(env, name), value)
    cursor = json_skip(codes, after_value)
    if cursor < codes.length() && codes[cursor] == ','.to_int() {
      cursor = json_skip(codes, cursor + 1)
    } else if cursor < codes.length() && codes[cursor] == '}'.to_int() {
      return (@value.Map(map), cursor + 1)
    } else {
      raise EvalError::Cannot("decode")
    }
  }
  raise EvalError::Cannot("decode")
}

///|
fn json_array(
  env : Env,
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int) raise EvalError {
  let block = @value.Series::block()
  let mut cursor = json_skip(codes, at)
  if cursor < codes.length() && codes[cursor] == ']'.to_int() {
    return (@value.Seq(block, 0), cursor + 1)
  }
  while cursor < codes.length() {
    let (value, after) = json_value(env, codes, cursor)
    block.push_item(value) |> ignore
    cursor = json_skip(codes, after)
    if cursor < codes.length() && codes[cursor] == ','.to_int() {
      cursor = json_skip(codes, cursor + 1)
    } else if cursor < codes.length() && codes[cursor] == ']'.to_int() {
      return (@value.Seq(block, 0), cursor + 1)
    } else {
      raise EvalError::Cannot("decode")
    }
  }
  raise EvalError::Cannot("decode")
}

///|
fn json_string(codes : Array[Int], at : Int) -> (String, Int) raise EvalError {
  let buf = StringBuilder()
  let mut cursor = at
  while cursor < codes.length() && codes[cursor] != '"'.to_int() {
    if codes[cursor] == '\\'.to_int() {
      if cursor + 1 >= codes.length() {
        raise EvalError::Cannot("decode")
      }
      let mark = codes[cursor + 1]
      if mark == 'u'.to_int() {
        if cursor + 5 >= codes.length() {
          raise EvalError::Cannot("decode")
        }
        match json_hex4(codes, cursor + 2) {
          None => raise EvalError::Cannot("decode")
          Some(code) =>
            match code.to_char() {
              Some(char) => buf.write_char(char)
              None => raise EvalError::Cannot("decode")
            }
        }
        cursor = cursor + 6
      } else {
        match json_escape(mark) {
          None => raise EvalError::Cannot("decode")
          Some(char) => buf.write_char(char)
        }
        cursor = cursor + 2
      }
    } else if codes[cursor] < 32 {
      raise EvalError::Cannot("decode")
    } else {
      buf.write_char(codes[cursor].to_char().unwrap())
      cursor = cursor + 1
    }
  }
  if cursor >= codes.length() {
    raise EvalError::Cannot("decode")
  }
  (buf.to_string(), cursor + 1)
}

///|
fn json_escape(mark : Int) -> Char? {
  if mark == '"'.to_int() {
    Some('"')
  } else if mark == '\\'.to_int() {
    Some('\\')
  } else if mark == '/'.to_int() {
    Some('/')
  } else if mark == 'b'.to_int() {
    Some('\u{0008}')
  } else if mark == 'f'.to_int() {
    Some('\u{000C}')
  } else if mark == 'n'.to_int() {
    Some('\n')
  } else if mark == 'r'.to_int() {
    Some('\r')
  } else if mark == 't'.to_int() {
    Some('\t')
  } else {
    None
  }
}

///|
fn json_number(codes : Array[Int], at : Int) -> (@value.Cell, Int)? {
  let mut cursor = at
  let mut negative = false
  if cursor < codes.length() && codes[cursor] == '-'.to_int() {
    negative = true
    cursor = cursor + 1
  }
  if cursor >= codes.length() || !json_digit(codes[cursor]) {
    return None
  }
  if codes[cursor] == '0'.to_int() &&
    cursor + 1 < codes.length() &&
    json_digit(codes[cursor + 1]) {
    return None
  }
  let mut whole = 0L
  while cursor < codes.length() && json_digit(codes[cursor]) {
    whole = whole * 10L + (codes[cursor] - '0'.to_int()).to_int64()
    cursor = cursor + 1
  }
  let mut fraction = false
  let mut scale = 1.0
  let mut frac = 0.0
  if cursor < codes.length() && codes[cursor] == '.'.to_int() {
    fraction = true
    cursor = cursor + 1
    if cursor >= codes.length() || !json_digit(codes[cursor]) {
      return None
    }
    while cursor < codes.length() && json_digit(codes[cursor]) {
      scale = scale * 10.0
      frac = frac + (codes[cursor] - '0'.to_int()).to_double() / scale
      cursor = cursor + 1
    }
  }
  let mut magnitude = whole.to_double() + frac
  let mut expo = false
  if cursor < codes.length() &&
    (codes[cursor] == 'e'.to_int() || codes[cursor] == 'E'.to_int()) {
    expo = true
    cursor = cursor + 1
    let mut exp_sign = 1
    if cursor < codes.length() && codes[cursor] == '+'.to_int() {
      cursor = cursor + 1
    } else if cursor < codes.length() && codes[cursor] == '-'.to_int() {
      exp_sign = -1
      cursor = cursor + 1
    }
    if cursor >= codes.length() || !json_digit(codes[cursor]) {
      return None
    }
    let mut exp = 0
    while cursor < codes.length() && json_digit(codes[cursor]) {
      exp = exp * 10 + codes[cursor] - '0'.to_int()
      cursor = cursor + 1
    }
    let mut power = 1.0
    for _ in 0..<exp {
      power = power * 10.0
    }
    if exp_sign < 0 {
      magnitude = magnitude / power
    } else {
      magnitude = magnitude * power
    }
  }
  let signed = if negative { 0.0 - magnitude } else { magnitude }
  if fraction || expo {
    Some((@value.Decimal(signed), cursor))
  } else {
    let int = if negative { 0L - whole } else { whole }
    Some((@value.Integer(int), cursor))
  }
}

///|
fn json_key(env : Env, name : String) -> @value.Cell {
  if json_word(name) {
    let sym = env.symbols.intern(name)
    @value.Sym(@value.Word, @value.Lexeme::make(sym, name))
  } else {
    text_series(name)
  }
}

///|
fn json_word(name : String) -> Bool {
  let codes : Array[Int] = []
  for char in name {
    codes.push(char.to_int())
  }
  if codes.length() == 0 || !json_word_start(codes[0]) {
    false
  } else {
    let mut ok = true
    for code in codes {
      if !json_word_char(code) {
        ok = false
      }
    }
    ok && !json_number_text(codes)
  }
}

///|
fn json_number_text(codes : Array[Int]) -> Bool {
  let mut cursor = 0
  if codes[cursor] == '+'.to_int() || codes[cursor] == '-'.to_int() {
    cursor = cursor + 1
  }
  if cursor >= codes.length() || !json_digit(codes[cursor]) {
    return false
  }
  while cursor < codes.length() && json_digit(codes[cursor]) {
    cursor = cursor + 1
  }
  if cursor < codes.length() && codes[cursor] == '.'.to_int() {
    cursor = cursor + 1
    if cursor >= codes.length() || !json_digit(codes[cursor]) {
      return false
    }
    while cursor < codes.length() && json_digit(codes[cursor]) {
      cursor = cursor + 1
    }
  }
  if cursor < codes.length() &&
    (codes[cursor] == 'e'.to_int() || codes[cursor] == 'E'.to_int()) {
    cursor = cursor + 1
    if cursor < codes.length() &&
      (codes[cursor] == '+'.to_int() || codes[cursor] == '-'.to_int()) {
      cursor = cursor + 1
    }
    if cursor >= codes.length() || !json_digit(codes[cursor]) {
      return false
    }
    while cursor < codes.length() && json_digit(codes[cursor]) {
      cursor = cursor + 1
    }
  }
  cursor == codes.length()
}

///|
fn json_word_start(code : Int) -> Bool {
  json_word_char(code) && !json_digit(code)
}

///|
fn json_word_char(code : Int) -> Bool {
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
  json_digit(code) ||
  code == '+'.to_int() ||
  code == '-'.to_int() ||
  code == '*'.to_int() ||
  code == '='.to_int() ||
  code == '<'.to_int() ||
  code == '>'.to_int() ||
  code == '?'.to_int() ||
  code == '!'.to_int() ||
  code == '.'.to_int() ||
  code == '_'.to_int() ||
  code == '\''.to_int() ||
  code == '&'.to_int() ||
  code == '|'.to_int() ||
  code == '~'.to_int() ||
  code == ':'.to_int()
}

///|
fn json_literal(codes : Array[Int], at : Int, text : String) -> Bool {
  let mut cursor = at
  let mut ok = true
  for char in text {
    if cursor >= codes.length() || codes[cursor] != char.to_int() {
      ok = false
    }
    cursor = cursor + 1
  }
  ok && (cursor >= codes.length() || json_boundary(codes[cursor]))
}

///|
fn json_boundary(code : Int) -> Bool {
  code == ' '.to_int() ||
  code == '\t'.to_int() ||
  code == '\n'.to_int() ||
  code == '\r'.to_int() ||
  code == ','.to_int() ||
  code == '}'.to_int() ||
  code == ']'.to_int() ||
  code == ':'.to_int()
}

///|
fn json_skip(codes : Array[Int], at : Int) -> Int {
  let mut cursor = at
  while cursor < codes.length() &&
        (
          codes[cursor] == ' '.to_int() ||
          codes[cursor] == '\t'.to_int() ||
          codes[cursor] == '\n'.to_int() ||
          codes[cursor] == '\r'.to_int()
        ) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn json_digit(code : Int) -> Bool {
  code >= '0'.to_int() && code <= '9'.to_int()
}

///|
fn json_hex4(codes : Array[Int], at : Int) -> Int? {
  let mut value = 0
  for index in at..<(at + 4) {
    match json_hex(codes[index]) {
      None => return None
      Some(digit) => value = value * 16 + digit
    }
  }
  Some(value)
}

///|
fn json_hex(code : Int) -> Int? {
  if json_digit(code) {
    Some(code - '0'.to_int())
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    Some(code - 'A'.to_int() + 10)
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    Some(code - 'a'.to_int() + 10)
  } else {
    None
  }
}
