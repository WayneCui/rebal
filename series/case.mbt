///|
pub fn lowercase(cell : @value.Cell) -> @value.Cell? {
  change_case(cell, false)
}

///|
pub fn uppercase(cell : @value.Cell) -> @value.Cell? {
  change_case(cell, true)
}

///|
pub fn deline(cell : @value.Cell) -> @value.Cell? {
  map_text(cell, fn(codes) {
    let next : Array[Int] = []
    let mut cursor = 0
    while cursor < codes.length() {
      let code = codes[cursor]
      if code == '\r'.to_int() {
        next.push('\n'.to_int())
        if cursor + 1 < codes.length() && codes[cursor + 1] == '\n'.to_int() {
          cursor = cursor + 2
        } else {
          cursor = cursor + 1
        }
      } else {
        next.push(code)
        cursor = cursor + 1
      }
    }
    next
  })
}

///|
pub fn enline(cell : @value.Cell) -> @value.Cell? {
  map_text(cell, fn(codes) {
    let next : Array[Int] = []
    let mut cursor = 0
    while cursor < codes.length() {
      let code = codes[cursor]
      if code == '\r'.to_int() &&
        cursor + 1 < codes.length() &&
        codes[cursor + 1] == '\n'.to_int() {
        next.push('\r'.to_int())
        next.push('\n'.to_int())
        cursor = cursor + 2
      } else if code == '\n'.to_int() {
        next.push('\r'.to_int())
        next.push('\n'.to_int())
        cursor = cursor + 1
      } else {
        next.push(code)
        cursor = cursor + 1
      }
    }
    next
  })
}

///|
pub fn detab(cell : @value.Cell) -> @value.Cell? {
  map_text(cell, fn(codes) {
    let next : Array[Int] = []
    let mut column = 0
    for code in codes {
      if code == '\t'.to_int() {
        let mut spaces = 4 - column % 4
        if spaces == 0 {
          spaces = 4
        }
        for _ in 0..<spaces {
          next.push(' '.to_int())
        }
        column = column + spaces
      } else {
        next.push(code)
        if code == '\n'.to_int() {
          column = 0
        } else {
          column = column + 1
        }
      }
    }
    next
  })
}

///|
pub fn entab(cell : @value.Cell) -> @value.Cell? {
  map_text(cell, fn(codes) {
    let next : Array[Int] = []
    let mut spaces = 0
    for code in codes {
      if code == ' '.to_int() {
        spaces = spaces + 1
      } else {
        write_spaces(next, spaces)
        spaces = 0
        next.push(code)
      }
    }
    write_spaces(next, spaces)
    next
  })
}

///|
pub fn dehex(cell : @value.Cell) -> @value.Cell? {
  dehex_with(cell, '%'.to_int(), false)
}

///|
/// `escape` is the mark before two hex digits. `/uri` turns `+` into a space,
/// or `_` when the mark is `=`.
pub fn dehex_with(cell : @value.Cell, escape : Int, uri : Bool) -> @value.Cell? {
  let space = if escape == '='.to_int() { '_'.to_int() } else { '+'.to_int() }
  map_codes(cell, fn(codes) {
    let next : Array[Int] = []
    let mut cursor = 0
    while cursor < codes.length() {
      if codes[cursor] == escape && cursor + 2 < codes.length() {
        match (hex_value(codes[cursor + 1]), hex_value(codes[cursor + 2])) {
          (Some(high), Some(low)) => {
            next.push(high * 16 + low)
            cursor = cursor + 3
          }
          _ => {
            next.push(codes[cursor])
            cursor = cursor + 1
          }
        }
      } else if uri && codes[cursor] == space {
        next.push(' '.to_int())
        cursor = cursor + 1
      } else {
        next.push(codes[cursor])
        cursor = cursor + 1
      }
    }
    next
  })
}

///|
pub fn enhex(cell : @value.Cell) -> @value.Cell? {
  enhex_with(cell, false)
}

///|
pub fn enhex_with(cell : @value.Cell, plus : Bool) -> @value.Cell? {
  let uri = match cell {
    @value.Seq(series, _) =>
      series.datatype() == @value.File || series.datatype() == @value.Url
    _ => false
  }
  let binary = match cell {
    @value.Seq(series, _) => series.datatype() == @value.Binary
    _ => false
  }
  map_codes(cell, fn(codes) { encode_hex(codes, uri, binary, plus) })
}

///|
fn change_case(cell : @value.Cell, upper : Bool) -> @value.Cell? {
  match cell {
    @value.Char(code) =>
      Some(@value.Char(if upper { upper_code(code) } else { lower_code(code) }))
    _ =>
      map_text(cell, fn(codes) {
        let next : Array[Int] = []
        for code in codes {
          next.push(if upper { upper_code(code) } else { lower_code(code) })
        }
        next
      })
  }
}

///|
fn map_codes(
  cell : @value.Cell,
  produce : (Array[Int]) -> Array[Int],
) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) if @value.text_series(series.datatype()) => {
      let codes : Array[Int] = []
      for cursor in index..<series.length() {
        match series.code(cursor) {
          Some(code) => codes.push(code)
          None => ()
        }
      }
      let next = produce(codes)
      while series.length() > index {
        series.remove_code(index) |> ignore
      }
      for code in next {
        series.push_code(code) |> ignore
      }
      Some(cell)
    }
    Some((series, index)) if series.datatype() == @value.Binary => {
      let codes : Array[Int] = []
      for cursor in index..<series.length() {
        match series.byte_at(cursor) {
          Some(byte) => codes.push(byte.to_int())
          None => ()
        }
      }
      let next = produce(codes)
      while series.length() > index {
        series.remove_byte(index) |> ignore
      }
      for code in next {
        series.push_byte(code.to_byte()) |> ignore
      }
      Some(cell)
    }
    _ => None
  }
}

///|
fn map_text(
  cell : @value.Cell,
  produce : (Array[Int]) -> Array[Int],
) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) if series.datatype() == @value.String => {
      let codes : Array[Int] = []
      for cursor in index..<series.length() {
        match series.code(cursor) {
          Some(code) => codes.push(code)
          None => ()
        }
      }
      let next = produce(codes)
      while series.length() > index {
        series.remove_code(index) |> ignore
      }
      for code in next {
        series.push_code(code) |> ignore
      }
      Some(cell)
    }
    _ => None
  }
}

///|
fn write_spaces(next : Array[Int], count : Int) -> Unit {
  let mut spaces = count
  while spaces >= 4 {
    next.push('\t'.to_int())
    spaces = spaces - 4
  }
  while spaces > 0 {
    next.push(' '.to_int())
    spaces = spaces - 1
  }
}

///|
fn lower_code(code : Int) -> Int {
  if code >= 'A'.to_int() && code <= 'Z'.to_int() {
    code + ('a'.to_int() - 'A'.to_int())
  } else {
    code
  }
}

///|
fn upper_code(code : Int) -> Int {
  if code >= 'a'.to_int() && code <= 'z'.to_int() {
    code - ('a'.to_int() - 'A'.to_int())
  } else {
    code
  }
}

///|
fn encode_hex(
  codes : Array[Int],
  uri : Bool,
  binary : Bool,
  plus : Bool,
) -> Array[Int] {
  let next : Array[Int] = []
  for code in codes {
    let bytes = if binary { [code] } else { utf8_codes(code) }
    for byte in bytes {
      if plus && byte == ' '.to_int() {
        next.push('+'.to_int())
      } else if stays_plain(byte, uri) && !(plus && byte == '+'.to_int()) {
        next.push(byte)
      } else {
        next.push('%'.to_int())
        next.push(hex_digit_code(byte / 16))
        next.push(hex_digit_code(byte % 16))
      }
    }
  }
  next
}

///|
fn utf8_codes(code : Int) -> Array[Int] {
  let bytes : Array[Int] = []
  if code < 0x80 {
    bytes.push(code)
  } else if code < 0x800 {
    bytes.push(0xC0 + code / 64)
    bytes.push(0x80 + code % 64)
  } else if code < 0x10000 {
    bytes.push(0xE0 + code / 4096)
    bytes.push(0x80 + code / 64 % 64)
    bytes.push(0x80 + code % 64)
  } else {
    bytes.push(0xF0 + code / 262144)
    bytes.push(0x80 + code / 4096 % 64)
    bytes.push(0x80 + code / 64 % 64)
    bytes.push(0x80 + code % 64)
  }
  bytes
}

///|
fn stays_plain(code : Int, uri : Bool) -> Bool {
  if plain_code(code) || component_mark(code) {
    true
  } else {
    uri && uri_mark(code)
  }
}

///|
fn component_mark(code : Int) -> Bool {
  code == '!'.to_int() ||
  code == '\''.to_int() ||
  code == '('.to_int() ||
  code == ')'.to_int() ||
  code == '*'.to_int()
}

///|
fn uri_mark(code : Int) -> Bool {
  code == ';'.to_int() ||
  code == ','.to_int() ||
  code == '/'.to_int() ||
  code == '?'.to_int() ||
  code == ':'.to_int() ||
  code == '@'.to_int() ||
  code == '&'.to_int() ||
  code == '='.to_int() ||
  code == '+'.to_int() ||
  code == '$'.to_int() ||
  code == '#'.to_int()
}

///|
fn plain_code(code : Int) -> Bool {
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
  code == '-'.to_int() ||
  code == '_'.to_int() ||
  code == '.'.to_int() ||
  code == '~'.to_int()
}

///|
fn hex_value(code : Int) -> Int? {
  if code >= '0'.to_int() && code <= '9'.to_int() {
    Some(code - '0'.to_int())
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    Some(code - 'A'.to_int() + 10)
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    Some(code - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn hex_digit_code(value : Int) -> Int {
  if value < 10 {
    '0'.to_int() + value
  } else {
    'A'.to_int() + value - 10
  }
}
