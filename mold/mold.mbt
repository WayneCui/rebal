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
      @value.Percent(n) => buf.write_string(percent_text(n))
      @value.Pair(x, y) => {
        buf.write_string(x.to_string())
        buf.write_char('x')
        buf.write_string(y.to_string())
      }
      @value.Tuple(parts) => write_tuple(buf, parts)
      @value.Money(n) =>
        if n < 0.0 {
          buf.write_char('-')
          buf.write_char('$')
          buf.write_string(money_text(0.0 - n))
        } else {
          buf.write_char('$')
          buf.write_string(money_text(n))
        }
      @value.Time(n) => write_time(buf, n)
      @value.Date(date) => write_date(buf, date)
      @value.Char(code) => write_char_value(buf, code, molded)
      @value.Sym(datatype, lexeme) =>
        write_word(buf, datatype, lexeme.spelling())
      @value.Seq(series, index) =>
        write_series(buf, series, index, molded, depth)
      @value.Type(datatype) => buf.write_string(type_name(datatype))
      @value.Function(func) =>
        if func.is_closure() {
          buf.write_string("closure!")
        } else if func.is_infix() {
          buf.write_string("op!")
        } else {
          buf.write_string("function!")
        }
      @value.Object(_) => buf.write_string("object!")
      @value.Module(_) => buf.write_string("module!")
      @value.Port(_) => buf.write_string("port!")
      @value.Handle(handle) => {
        buf.write_string("#(handle! ")
        buf.write_string(handle.kind())
        buf.write_string(")")
      }
      @value.Bitset(bits) => write_bitset(buf, bits)
      @value.Vector(vector) => write_vector(buf, vector, molded)
      @value.Image(image) => write_image(buf, image)
      @value.Map(map) => write_map(buf, map, molded, depth)
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
    @value.File => write_file(buf, series, index, molded)
    @value.Email | @value.Url => write_codes(buf, series, index)
    @value.Tag => write_wrapped(buf, series, index, molded, "<", ">")
    @value.Issue => write_wrapped(buf, series, index, molded, "#", "")
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
fn write_codes(
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
) -> Unit {
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.code(cursor) {
      Some(code) => write_raw(buf, code)
      None => ()
    }
    cursor = cursor + 1
  }
}

///|
fn write_wrapped(
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
  molded : Bool,
  prefix : String,
  suffix : String,
) -> Unit {
  if molded {
    buf.write_string(prefix)
  }
  write_codes(buf, series, index)
  if molded {
    buf.write_string(suffix)
  }
}

///|
fn write_file(
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
  molded : Bool,
) -> Unit {
  if !molded {
    write_codes(buf, series, index)
  } else {
    let start = if index < 0 { 0 } else { index }
    if start >= series.length() {
      buf.write_string("%\"\"")
    } else {
      buf.write_char('%')
      let mut cursor = start
      while cursor < series.length() {
        match series.code(cursor) {
          Some(code) =>
            if plain_file_code(code) {
              write_raw(buf, code)
            } else {
              buf.write_char('%')
              buf.write_char(hex_char(code / 16))
              buf.write_char(hex_char(code % 16))
            }
          None => ()
        }
        cursor = cursor + 1
      }
    }
  }
}

///|
fn plain_file_code(code : Int) -> Bool {
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  code == '/'.to_int() ||
  code == '.'.to_int() ||
  code == '-'.to_int() ||
  code == '_'.to_int() ||
  code == '~'.to_int() ||
  code == '+'.to_int()
}

///|
fn hex_char(n : Int) -> Char {
  let digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  digits[n % 16]
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
fn write_date(buf : StringBuilder, date : @value.DateValue) -> Unit {
  buf.write_string(date.day().to_string())
  buf.write_char('-')
  buf.write_string(month_name(date.month()))
  buf.write_char('-')
  buf.write_string(year_text(date.year()))
  match date.time() {
    Some(seconds) => {
      buf.write_char('/')
      write_time(buf, seconds)
    }
    None => ()
  }
  match date.zone() {
    Some(minutes) =>
      if minutes < 0 {
        buf.write_char('-')
        write_time(buf, (0 - minutes).to_double() * 60.0)
      } else {
        buf.write_char('+')
        write_time(buf, minutes.to_double() * 60.0)
      }
    None => ()
  }
}

///|
fn month_name(month : Int) -> String {
  if month == 1 {
    "Jan"
  } else if month == 2 {
    "Feb"
  } else if month == 3 {
    "Mar"
  } else if month == 4 {
    "Apr"
  } else if month == 5 {
    "May"
  } else if month == 6 {
    "Jun"
  } else if month == 7 {
    "Jul"
  } else if month == 8 {
    "Aug"
  } else if month == 9 {
    "Sep"
  } else if month == 10 {
    "Oct"
  } else if month == 11 {
    "Nov"
  } else {
    "Dec"
  }
}

///|
fn year_text(year : Int) -> String {
  let mut text = year.to_string()
  while text.length() < 4 {
    text = "0" + text
  }
  text
}

///|
fn write_time(buf : StringBuilder, seconds : Double) -> Unit {
  let snapped = @value.snap_seconds(seconds)
  if snapped < 0.0 {
    buf.write_char('-')
  }
  let magnitude = if snapped < 0.0 { 0.0 - snapped } else { snapped }
  let total = (magnitude * 1000000000.0 + 0.5).to_int64()
  let hour = total / 3600000000000L
  let after_hour = total % 3600000000000L
  let minute = after_hour / 60000000000L
  let after_minute = after_hour % 60000000000L
  let second = after_minute / 1000000000L
  let nano = after_minute % 1000000000L
  buf.write_string(hour.to_string())
  buf.write_char(':')
  buf.write_string(two_digits(minute))
  if second != 0L || nano != 0L {
    buf.write_char(':')
    buf.write_string(two_digits(second))
    let fraction = nano_text(nano)
    if fraction.length() > 0 {
      buf.write_char('.')
      buf.write_string(fraction)
    }
  }
}

///|
fn two_digits(value : Int64) -> String {
  if value < 10L {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn nano_text(nano : Int64) -> String {
  if nano <= 0L {
    ""
  } else {
    let mut text = nano.to_string()
    while text.length() < 9 {
      text = "0" + text
    }
    let mut end = text.length()
    while end > 0 && text[end - 1:end].to_owned() == "0" {
      end = end - 1
    }
    text[0:end].to_owned()
  }
}

///|
fn money_text(value : Double) -> String {
  let text = value.to_string()
  let mut expo = false
  for char in text {
    if char == 'e' || char == 'E' {
      expo = true
    }
  }
  if !expo &&
    text.length() >= 2 &&
    text[text.length() - 2:text.length()].to_owned() == ".0" {
    text[0:text.length() - 2].to_owned()
  } else {
    text
  }
}

///|
fn write_tuple(buf : StringBuilder, parts : Array[Int]) -> Unit {
  let mut index = 0
  for part in parts {
    if index > 0 {
      buf.write_char('.')
    }
    buf.write_string(part.to_string())
    index = index + 1
  }
}

///|
fn percent_text(value : Double) -> String {
  let text = (value * 100.0).to_string()
  let mut expo = false
  for char in text {
    if char == 'e' || char == 'E' {
      expo = true
    }
  }
  if !expo &&
    text.length() >= 2 &&
    text[text.length() - 2:text.length()].to_owned() == ".0" {
    text[0:text.length() - 2].to_owned() + "%"
  } else {
    text + "%"
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
fn write_map(
  buf : StringBuilder,
  map : @value.MapValue,
  molded : Bool,
  depth : Int,
) -> Unit {
  buf.write_string("make map! [")
  for index in 0..<map.length() {
    if index > 0 {
      buf.write_char(' ')
    }
    match (map.key(index), map.value(index)) {
      (Some(key), Some(value)) => {
        write_cell(buf, key, molded, depth + 1)
        buf.write_char(' ')
        write_cell(buf, value, molded, depth + 1)
      }
      _ => ()
    }
  }
  buf.write_char(']')
}

///|
fn write_vector(
  buf : StringBuilder,
  vector : @value.Vector,
  molded : Bool,
) -> Unit {
  if molded {
    buf.write_string("#(")
    buf.write_string(vector.kind().label())
    buf.write_string(" [")
  }
  let count = vector.length()
  for index in 0..<count {
    if index > 0 {
      buf.write_char(' ')
    }
    match vector.at(index + 1) {
      Some(cell) => write_cell(buf, cell, false, 0)
      None => ()
    }
  }
  if molded {
    buf.write_string("])")
  }
}

///|
/// Form and mold both use construction syntax. Ten or more pixels break lines.
fn write_image(buf : StringBuilder, image : @value.Image) -> Unit {
  buf.write_string("make image! [")
  buf.write_string(image.width().to_string())
  buf.write_string("x")
  buf.write_string(image.height().to_string())
  buf.write_string(" #{")
  let count = image.length()
  let flat = count < 10
  write_image_bytes(buf, image.channel_bytes("rgb"), 3, flat)
  if image.has_alpha() {
    if !flat {
      buf.write_char('\n')
    }
    buf.write_string("} #{")
    write_image_bytes(buf, image.channel_bytes("alpha"), 1, flat)
  }
  if !flat && count != 0 {
    buf.write_char('\n')
  }
  buf.write_string("}]")
}

///|
fn write_image_bytes(
  buf : StringBuilder,
  bytes : Array[Int],
  stride : Int,
  flat : Bool,
) -> Unit {
  let count = if stride == 0 { 0 } else { bytes.length() / stride }
  for index in 0..<count {
    if !flat && index % 10 == 0 {
      buf.write_char('\n')
    }
    for offset in 0..<stride {
      write_hex_byte(buf, bytes[index * stride + offset])
    }
  }
}

///|
fn write_bitset(buf : StringBuilder, bits : @value.Bitset) -> Unit {
  buf.write_string("make bitset! #{")
  for index in 0..<32 {
    write_hex_byte(buf, bits.byte(index))
  }
  buf.write_string("}")
}

///|
pub fn type_name(datatype : @value.Datatype) -> String {
  match datatype {
    @value.Unset => "unset!"
    @value.None => "none!"
    @value.Logic => "logic!"
    @value.Integer => "integer!"
    @value.Decimal => "decimal!"
    @value.Percent => "percent!"
    @value.Pair => "pair!"
    @value.Tuple => "tuple!"
    @value.Money => "money!"
    @value.Time => "time!"
    @value.Date => "date!"
    @value.Char => "char!"
    @value.Word => "word!"
    @value.SetWord => "set-word!"
    @value.GetWord => "get-word!"
    @value.LitWord => "lit-word!"
    @value.Refinement => "refinement!"
    @value.String => "string!"
    @value.File => "file!"
    @value.Email => "email!"
    @value.Url => "url!"
    @value.Tag => "tag!"
    @value.Issue => "issue!"
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
    @value.Bitset => "bitset!"
    @value.Map => "map!"
    @value.Module => "module!"
    @value.Closure => "closure!"
    @value.Port => "port!"
    @value.Handle => "handle!"
    @value.Vector => "vector!"
    @value.Image => "image!"
  }
}
