///|
/// CSV and TSV, as in codec-csv.reb. A block of rows gets one line each.
/// Strings and words are quoted. `none` is an empty field. Decode returns
/// blocks of strings.
fn encode_csv(
  value : @value.Cell,
  delimiter : Int,
) -> @value.Cell raise EvalError {
  text_series(csv_encode(value, delimiter))
}

///|
fn decode_csv(
  value : @value.Cell,
  delimiter : Int,
) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, _) if series.datatype() == @value.File =>
      source_text(value)
    _ => string_text(value)
  }
  csv_table(text, delimiter)
}

///|
fn csv_encode(value : @value.Cell, delimiter : Int) -> String raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      if csv_rows(series, index) {
        let buf = StringBuilder()
        let mut cursor = if index < 0 { 0 } else { index }
        while cursor < series.length() {
          match series.item(cursor) {
            Some(row) => {
              buf.write_string(csv_line(row, delimiter))
              buf.write_char('\n')
            }
            None => ()
          }
          cursor = cursor + 1
        }
        buf.to_string()
      } else {
        csv_line(value, delimiter)
      }
    _ => raise EvalError::Cannot("encode")
  }
}

///|
fn csv_rows(series : @value.Series, index : Int) -> Bool {
  match series.item(if index < 0 { 0 } else { index }) {
    Some(@value.Seq(row, _)) => row.datatype() == @value.Block
    _ => false
  }
}

///|
fn csv_line(value : @value.Cell, delimiter : Int) -> String raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let buf = StringBuilder()
      let mut cursor = if index < 0 { 0 } else { index }
      let mut first = true
      while cursor < series.length() {
        if !first {
          match delimiter.to_char() {
            Some(char) => buf.write_char(char)
            None => ()
          }
        }
        first = false
        match series.item(cursor) {
          Some(item) => buf.write_string(csv_field(item))
          None => ()
        }
        cursor = cursor + 1
      }
      buf.to_string()
    }
    _ => raise EvalError::Cannot("encode")
  }
}

///|
fn csv_field(value : @value.Cell) -> String raise EvalError {
  match value {
    @value.Cell::None => ""
    @value.Integer(_)
    | @value.Decimal(_)
    | @value.Percent(_)
    | @value.Time(_) => @mold.form_text(value)
    @value.Money(_) => csv_money(@mold.form_text(value))
    @value.Date(date) => csv_date(date)
    @value.Char(_) | @value.Sym(_, _) | @value.Seq(_, _) =>
      csv_quote(string_text(value))
    _ => raise EvalError::Cannot("encode")
  }
}

///|
fn csv_money(text : String) -> String {
  let buf = StringBuilder()
  let mut seen = false
  for char in text {
    if seen {
      buf.write_char(char)
    } else if char == '$' {
      seen = true
    }
  }
  if seen {
    buf.to_string()
  } else {
    text
  }
}

///|
fn csv_date(date : @value.DateValue) -> String {
  let buf = StringBuilder()
  buf.write_string(csv_pad(date.year(), 4))
  buf.write_char('-')
  buf.write_string(csv_pad(date.month(), 2))
  buf.write_char('-')
  buf.write_string(csv_pad(date.day(), 2))
  match date.time() {
    Some(seconds) => {
      let whole = seconds.to_int()
      let hour = whole / 3600
      let minute = whole % 3600 / 60
      let second = whole % 60
      buf.write_char(' ')
      buf.write_string(csv_pad(hour, 2))
      buf.write_char(':')
      buf.write_string(csv_pad(minute, 2))
      buf.write_char(':')
      buf.write_string(csv_pad(second, 2))
    }
    None => ()
  }
  buf.to_string()
}

///|
fn csv_pad(value : Int, width : Int) -> String {
  let text = value.to_string()
  let buf = StringBuilder()
  let mut count = 0
  for char in text {
    let _ = char
    count = count + 1
  }
  while count < width {
    buf.write_char('0')
    count = count + 1
  }
  buf.write_string(text)
  buf.to_string()
}

///|
fn csv_quote(text : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for char in text {
    if char == '"' {
      buf.write_char('"')
    }
    buf.write_char(char)
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn csv_table(text : String, delimiter : Int) -> @value.Cell {
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  let mut at = 0
  if codes.length() >= 1 && codes[0] == 0xFEFF {
    at = 1
  }
  let rows = @value.Series::block()
  while at < codes.length() {
    let row = @value.Series::block()
    let mut more = true
    while more {
      let (field, next, broken) = csv_value(codes, at, delimiter)
      row.push_item(text_series(field)) |> ignore
      at = next
      more = !broken
    }
    rows.push_item(@value.Seq(row, 0)) |> ignore
  }
  @value.Seq(rows, 0)
}

///|
fn csv_value(
  codes : Array[Int],
  at : Int,
  delimiter : Int,
) -> (String, Int, Bool) {
  if at < codes.length() && codes[at] == '"'.to_int() {
    csv_quoted(codes, at + 1, delimiter)
  } else {
    csv_raw(codes, at, delimiter)
  }
}

///|
fn csv_quoted(
  codes : Array[Int],
  at : Int,
  delimiter : Int,
) -> (String, Int, Bool) {
  let buf = StringBuilder()
  let mut index = at
  let mut closed = false
  while index < codes.length() && !closed {
    if codes[index] == '"'.to_int() {
      if index + 1 < codes.length() && codes[index + 1] == '"'.to_int() {
        buf.write_char('"')
        index = index + 2
      } else {
        closed = true
        index = index + 1
      }
    } else {
      match codes[index].to_char() {
        Some(char) => buf.write_char(char)
        None => ()
      }
      index = index + 1
    }
  }
  while index < codes.length() &&
        codes[index] != delimiter &&
        codes[index] != 13 &&
        codes[index] != 10 {
    match codes[index].to_char() {
      Some(char) => buf.write_char(char)
      None => ()
    }
    index = index + 1
  }
  let (next, broken) = csv_break(codes, index, delimiter)
  (buf.to_string(), next, broken)
}

///|
fn csv_raw(
  codes : Array[Int],
  at : Int,
  delimiter : Int,
) -> (String, Int, Bool) {
  let buf = StringBuilder()
  let mut index = at
  while index < codes.length() &&
        codes[index] != delimiter &&
        codes[index] != 13 &&
        codes[index] != 10 {
    match codes[index].to_char() {
      Some(char) => buf.write_char(char)
      None => ()
    }
    index = index + 1
  }
  let (next, broken) = csv_break(codes, index, delimiter)
  (buf.to_string(), next, broken)
}

///|
fn csv_break(codes : Array[Int], at : Int, delimiter : Int) -> (Int, Bool) {
  if at >= codes.length() {
    (at, true)
  } else if codes[at] == delimiter {
    (at + 1, false)
  } else if codes[at] == 13 {
    if at + 1 < codes.length() && codes[at + 1] == 10 {
      (at + 2, true)
    } else {
      (at + 1, true)
    }
  } else if codes[at] == 10 {
    (at + 1, true)
  } else {
    (at, true)
  }
}
