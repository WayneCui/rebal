///|
/// Definite-length DER. Constructed values become blocks.
/// UTCTime becomes a date. The other primitive values stay bytes,
/// except the byte-string tags, which become strings.
fn decode_der(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = payload_bytes(value, "decode")
  match der_span(env, bytes, 0, bytes.length()) {
    Some(items) => der_block(items)
    None => @value.None
  }
}

///|
fn der_span(
  env : Env,
  bytes : Array[Int],
  start : Int,
  end : Int,
) -> Array[@value.Cell]? raise EvalError {
  if start > end {
    None
  } else {
    let items : Array[@value.Cell] = []
    let mut cursor = start
    let mut ok = true
    while ok && cursor < end {
      match der_value(env, bytes, cursor, end) {
        Some(found) => {
          items.push(found.0)
          items.push(found.1)
          cursor = found.2
        }
        None => ok = false
      }
    }
    if ok && cursor == end {
      Some(items)
    } else {
      None
    }
  }
}

///|
fn der_value(
  env : Env,
  bytes : Array[Int],
  at : Int,
  end : Int,
) -> (@value.Cell, @value.Cell, Int)? raise EvalError {
  if at >= end {
    None
  } else {
    let head = bytes[at]
    let class = head / 64
    let constructed = (head & 32) != 0
    let number = head & 31
    if number == 31 {
      None
    } else {
      match der_length(bytes, at + 1, end) {
        None => None
        Some(sized) => {
          let content = sized.0
          let finish = sized.1
          let name = der_word(env, class, number)
          if constructed {
            match der_span(env, bytes, content, finish) {
              Some(items) => Some((name, der_block(items), finish))
              None => None
            }
          } else {
            Some(
              (
                name,
                der_primitive(
                  class,
                  number,
                  slice_from(bytes, content, finish - content),
                ),
                finish,
              ),
            )
          }
        }
      }
    }
  }
}

///|
fn der_length(bytes : Array[Int], at : Int, end : Int) -> (Int, Int)? {
  if at >= end {
    None
  } else {
    let first = bytes[at]
    if first < 128 {
      let finish = at + 1 + first
      if finish > end {
        None
      } else {
        Some((at + 1, finish))
      }
    } else if first == 128 || first > 131 {
      None
    } else {
      let count = first - 128
      if at + count >= end {
        None
      } else {
        let mut length = 0
        let mut index = 0
        while index < count {
          length = length * 256 + bytes[at + 1 + index]
          index = index + 1
        }
        let content = at + 1 + count
        let finish = content + length
        if finish > end {
          None
        } else {
          Some((content, finish))
        }
      }
    }
  }
}

///|
fn der_primitive(class : Int, number : Int, bytes : Array[Int]) -> @value.Cell {
  if class == 0 && number == 23 {
    match read_utc(latin_text(bytes)) {
      Some(date) => @value.Date(date)
      None => binary_cell(bytes)
    }
  } else if class == 0 && der_text(number) {
    text_series(latin_text(bytes))
  } else {
    binary_cell(bytes)
  }
}

///|
fn der_text(number : Int) -> Bool {
  number == 12 ||
  number == 18 ||
  number == 19 ||
  number == 20 ||
  number == 22 ||
  number == 26
}

///|
fn der_word(env : Env, class : Int, number : Int) -> @value.Cell {
  let spelling = if class == 0 {
    universal_name(number)
  } else if class == 1 {
    "AP" + number.to_string()
  } else if class == 2 {
    "CS" + number.to_string()
  } else {
    "PR" + number.to_string()
  }
  let sym = env.symbols.intern(spelling)
  @value.Sym(@value.Word, @value.Lexeme::make(sym, spelling))
}

///|
fn universal_name(number : Int) -> String {
  if number == 1 {
    "BOOLEAN"
  } else if number == 2 {
    "INTEGER"
  } else if number == 3 {
    "BIT_STRING"
  } else if number == 4 {
    "OCTET_STRING"
  } else if number == 5 {
    "NULL"
  } else if number == 6 {
    "OBJECT_IDENTIFIER"
  } else if number == 12 {
    "UTF8_STRING"
  } else if number == 16 {
    "SEQUENCE"
  } else if number == 17 {
    "SET"
  } else if number == 19 {
    "PRINTABLE_STRING"
  } else if number == 22 {
    "IA5_STRING"
  } else if number == 23 {
    "UTC_TIME"
  } else if number == 24 {
    "GENERALIZED_TIME"
  } else {
    "UNDEFINED"
  }
}

///|
fn der_block(items : Array[@value.Cell]) -> @value.Cell {
  let block = @value.Series::block()
  for item in items {
    block.push_item(item) |> ignore
  }
  @value.Seq(block, 0)
}
