///|
/// HTML character references, as in codec-html-entities.reb.
/// A reference that is not a character stays in the text, including the `&`.
fn decode_html(value : @value.Cell) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, index) if series.datatype() == @value.File =>
      read_file(text_from(series, index))
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      text_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      qp_text(bytes_from(series, index))
    _ => raise EvalError::Cannot("decode")
  }
  text_series(html_text(text))
}

///|
fn html_text(text : String) -> String {
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  let buf = StringBuilder()
  let mut cursor = 0
  while cursor < codes.length() {
    if codes[cursor] != '&'.to_int() {
      buf.write_char(codes[cursor].to_char().unwrap())
      cursor = cursor + 1
    } else {
      match html_ref(codes, cursor + 1) {
        Some((code, next)) => {
          buf.write_char(code.to_char().unwrap())
          cursor = next
        }
        None => {
          buf.write_char('&')
          cursor = cursor + 1
        }
      }
    }
  }
  buf.to_string()
}

///|
fn html_ref(codes : Array[Int], at : Int) -> (Int, Int)? {
  if at >= codes.length() {
    None
  } else if codes[at] == '#'.to_int() {
    html_number(codes, at + 1)
  } else {
    html_named(codes, at)
  }
}

///|
fn html_number(codes : Array[Int], at : Int) -> (Int, Int)? {
  if at < codes.length() && codes[at] == 'x'.to_int() {
    html_digits(codes, at + 1, true)
  } else {
    html_digits(codes, at, false)
  }
}

///|
fn html_digits(codes : Array[Int], at : Int, hex : Bool) -> (Int, Int)? {
  let limit = if hex { 8 } else { 7 }
  let mut end = at
  let mut count = 0
  while count < limit && end < codes.length() && html_digit(codes[end], hex) {
    end = end + 1
    count = count + 1
  }
  if count == 0 || end >= codes.length() || codes[end] != ';'.to_int() {
    None
  } else {
    let mut value = 0
    for index in at..<end {
      value = value * (if hex { 16 } else { 10 }) +
        html_digit_value(codes[index])
    }
    html_char(value, end + 1)
  }
}

///|
fn html_named(codes : Array[Int], at : Int) -> (Int, Int)? {
  let mut end = at
  let mut count = 0
  while count < 10 && end < codes.length() && html_alnum(codes[end]) {
    end = end + 1
    count = count + 1
  }
  if count == 0 || end >= codes.length() || codes[end] != ';'.to_int() {
    None
  } else {
    let buf = StringBuilder()
    for index in at..<end {
      buf.write_char(codes[index].to_char().unwrap())
    }
    match html_name(buf.to_string()) {
      Some(code) => html_char(code, end + 1)
      None => None
    }
  }
}

///|
fn html_char(code : Int, next : Int) -> (Int, Int)? {
  match code.to_char() {
    Some(_) => Some((code, next))
    None => None
  }
}

///|
fn html_alnum(code : Int) -> Bool {
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int())
}

///|
fn html_digit(code : Int, hex : Bool) -> Bool {
  if code >= '0'.to_int() && code <= '9'.to_int() {
    true
  } else if hex &&
    (
      (code >= 'A'.to_int() && code <= 'F'.to_int()) ||
      (code >= 'a'.to_int() && code <= 'f'.to_int())
    ) {
    true
  } else {
    false
  }
}

///|
fn html_digit_value(code : Int) -> Int {
  if code >= '0'.to_int() && code <= '9'.to_int() {
    code - '0'.to_int()
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    code - 'A'.to_int() + 10
  } else {
    code - 'a'.to_int() + 10
  }
}
