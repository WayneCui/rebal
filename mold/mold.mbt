///|
let max_mold_depth : Int = 32

///|
/// Loadable text. A block is molded from its current index.
pub fn mold_text(cell : @value.Cell) -> String {
  let buf = StringBuilder()
  write_cell(buf, cell, true, 0)
  buf.to_string()
}

///|
/// Display text. Strings and characters are written without their literal marks.
pub fn form_text(cell : @value.Cell) -> String {
  let buf = StringBuilder()
  write_cell(buf, cell, false, 0)
  buf.to_string()
}

///|
pub fn cell(text : String) -> @value.Cell {
  let series = @value.Series::text()
  for char in text {
    series.push_code(char.to_int()) |> ignore
  }
  @value.Seq(series, 0)
}

///|
fn write_cell(
  buf : StringBuilder,
  cell : @value.Cell,
  molded : Bool,
  depth : Int,
) -> Unit {
  if depth > max_mold_depth {
    buf.write_string("...")
  } else {
    match cell {
      @value.Unset => if molded { buf.write_string("unset!") }
      @value.None => buf.write_string("none")
      @value.Logic(true) => buf.write_string("true")
      @value.Logic(false) => buf.write_string("false")
      @value.Integer(n) => buf.write_string(n.to_string())
      @value.Decimal(n) => buf.write_string(decimal_text(n))
      @value.Char(code) => write_char_value(buf, code, molded)
      @value.Sym(datatype, lexeme) =>
        write_word(buf, datatype, lexeme.spelling())
      @value.Seq(series, index) =>
        write_series(buf, series, index, molded, depth)
      @value.Type(datatype) => buf.write_string(type_name(datatype))
      @value.Function(func) =>
        if func.is_infix() {
          buf.write_string("op!")
        } else {
          buf.write_string("function!")
        }
      @value.Object(_) => buf.write_string("object!")
      @value.Error(error) => {
        buf.write_string("make error! [id: ")
        buf.write_string(error.id)
        buf.write_string(" arg1: ")
        write_string_literal(buf, error.arg1)
        buf.write_string("]")
      }
    }
  }
}

///|
fn write_word(
  buf : StringBuilder,
  datatype : @value.Datatype,
  spelling : String,
) -> Unit {
  match datatype {
    @value.SetWord => {
      buf.write_string(spelling)
      buf.write_char(':')
    }
    @value.GetWord => {
      buf.write_char(':')
      buf.write_string(spelling)
    }
    @value.LitWord => {
      buf.write_char('\'')
      buf.write_string(spelling)
    }
    @value.Refinement => {
      buf.write_char('/')
      buf.write_string(spelling)
    }
    _ => buf.write_string(spelling)
  }
}

///|
fn write_series(
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
  molded : Bool,
  depth : Int,
) -> Unit {
  match series.datatype() {
    @value.String => write_text(buf, series, index, molded)
    @value.Binary => write_binary(buf, series, index, molded)
    @value.Block =>
      if molded {
        write_items(buf, series, index, molded, depth, "[", "]", " ")
      } else {
        write_items(buf, series, index, molded, depth, "", "", " ")
      }
    @value.Paren =>
      if molded {
        write_items(buf, series, index, molded, depth, "(", ")", " ")
      } else {
        write_items(buf, series, index, molded, depth, "", "", " ")
      }
    @value.Path => write_items(buf, series, index, molded, depth, "", "", "/")
    @value.SetPath => {
      write_items(buf, series, index, molded, depth, "", "", "/")
      buf.write_char(':')
    }
    _ => buf.write_string(type_name(series.datatype()))
  }
}

///|
fn write_items(
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
  molded : Bool,
  depth : Int,
  open : String,
  close : String,
  sep : String,
) -> Unit {
  buf.write_string(open)
  let mut cursor = if index < 0 { 0 } else { index }
  let mut first = true
  while cursor < series.length() {
    if !first {
      buf.write_string(sep)
    }
    first = false
    match series.item(cursor) {
      Some(item) => write_cell(buf, item, molded, depth + 1)
      None => ()
    }
    cursor = cursor + 1
  }
  buf.write_string(close)
}

///|
fn write_text(
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
  molded : Bool,
) -> Unit {
  if molded {
    buf.write_char('"')
  }
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.code(cursor) {
      Some(code) =>
        if molded {
          write_escaped(buf, code)
        } else {
          write_raw(buf, code)
        }
      None => ()
    }
    cursor = cursor + 1
  }
  if molded {
    buf.write_char('"')
  }
}

///|
fn write_binary(
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
  molded : Bool,
) -> Unit {
  if molded {
    buf.write_string("#{")
  }
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.byte_at(cursor) {
      Some(byte) =>
        if molded {
          write_hex_byte(buf, byte.to_int())
        } else {
          write_raw(buf, byte.to_int())
        }
      None => ()
    }
    cursor = cursor + 1
  }
  if molded {
    buf.write_char('}')
  }
}

///|
fn write_char_value(buf : StringBuilder, code : Int, molded : Bool) -> Unit {
  if molded {
    buf.write_string("#\"")
    if code >= 32 && code <= 126 && code != '"'.to_int() && code != '^'.to_int() {
      write_raw(buf, code)
    } else {
      buf.write_string("^(")
      buf.write_string(hex(code))
      buf.write_char(')')
    }
    buf.write_char('"')
  } else {
    write_raw(buf, code)
  }
}

///|
fn write_string_literal(buf : StringBuilder, text : String) -> Unit {
  buf.write_char('"')
  for char in text {
    write_escaped(buf, char.to_int())
  }
  buf.write_char('"')
}

///|
fn write_escaped(buf : StringBuilder, code : Int) -> Unit {
  if code == '"'.to_int() {
    buf.write_string("^\"")
  } else if code == '^'.to_int() {
    buf.write_string("^^")
  } else if code == '\n'.to_int() {
    buf.write_string("^/")
  } else if code == '\t'.to_int() {
    buf.write_string("^-")
  } else if code == '\r'.to_int() {
    buf.write_string("^M")
  } else if code < 32 || code > 126 {
    buf.write_string("^(")
    buf.write_string(hex(code))
    buf.write_char(')')
  } else {
    write_raw(buf, code)
  }
}

///|
fn write_raw(buf : StringBuilder, code : Int) -> Unit {
  match code.to_char() {
    Some(char) => buf.write_char(char)
    None => ()
  }
}

///|
fn write_hex_byte(buf : StringBuilder, value : Int) -> Unit {
  buf.write_char(hex_digit(value / 16))
  buf.write_char(hex_digit(value % 16))
}

///|
fn hex(value : Int) -> String {
  if value < 0 {
    "0"
  } else if value < 16 {
    hex_digit(value).to_string()
  } else {
    hex(value / 16) + hex_digit(value % 16).to_string()
  }
}

///|
fn hex_digit(value : Int) -> Char {
  let n = if value < 0 { 0 } else if value > 15 { 15 } else { value }
  if n < 10 {
    ('0'.to_int() + n).to_char().unwrap()
  } else {
    ('A'.to_int() + n - 10).to_char().unwrap()
  }
}

///|
fn decimal_text(value : Double) -> String {
  let text = value.to_string()
  let mut dotted = false
  for char in text {
    if char == '.' || char == 'e' || char == 'E' {
      dotted = true
    }
  }
  if dotted {
    text
  } else {
    text + ".0"
  }
}

///|
pub fn type_name(datatype : @value.Datatype) -> String {
  match datatype {
    @value.Unset => "unset!"
    @value.None => "none!"
    @value.Logic => "logic!"
    @value.Integer => "integer!"
    @value.Decimal => "decimal!"
    @value.Char => "char!"
    @value.Word => "word!"
    @value.SetWord => "set-word!"
    @value.GetWord => "get-word!"
    @value.LitWord => "lit-word!"
    @value.Refinement => "refinement!"
    @value.String => "string!"
    @value.Binary => "binary!"
    @value.Block => "block!"
    @value.Paren => "paren!"
    @value.Path => "path!"
    @value.SetPath => "set-path!"
    @value.Datatype => "datatype!"
    @value.Function => "function!"
    @value.Op => "op!"
    @value.Object => "object!"
    @value.Error => "error!"
  }
}
