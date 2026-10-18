///|
/// The text codec is the native branch in sys-codec.reb. A binary is read as
/// UTF-8. Anything else is `mold/only`: a block loses its outer brackets, and
/// every other value is molded as usual. `/as` is accepted and ignored.
fn encode_text(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let text = qp_text(bytes_from(series, index)) catch {
        _ => raise EvalError::Cannot("encode")
      }
      text_series(text)
    }
    @value.Seq(series, _) if series.datatype() == @value.Block =>
      text_series(text_contents(@mold.mold_text(value)))
    _ => text_series(@mold.mold_text(value))
  }
}

///|
/// `load/as 'text` is `decode 'text`. A UTF-8 BOM is dropped. CR, LF, CRLF,
/// and LFCR all become a single line feed. Invalid UTF-8 is refused.
fn load_text(source : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = match source {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => utf8_bytes(source_text(source))
  }
  let text = qp_text(fold_newlines(drop_text_bom(bytes))) catch {
    _ => raise EvalError::Cannot("load")
  }
  text_series(text)
}

///|
fn drop_text_bom(bytes : Array[Int]) -> Array[Int] {
  if bytes.length() >= 3 &&
    bytes[0] == 0xEF &&
    bytes[1] == 0xBB &&
    bytes[2] == 0xBF {
    let rest : Array[Int] = []
    for index in 3..<bytes.length() {
      rest.push(bytes[index])
    }
    rest
  } else {
    bytes
  }
}

///|
fn fold_newlines(bytes : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index < bytes.length() {
    let byte = bytes[index]
    if byte == 13 {
      out.push(10)
      index = index + 1
      if index < bytes.length() && bytes[index] == 10 {
        index = index + 1
      }
    } else if byte == 10 {
      out.push(10)
      index = index + 1
      if index < bytes.length() && bytes[index] == 13 {
        index = index + 1
      }
    } else {
      out.push(byte)
      index = index + 1
    }
  }
  out
}

///|
fn text_contents(molded : String) -> String {
  let mut count = 0
  for char in molded {
    let _ = char
    count = count + 1
  }
  if count < 2 {
    molded
  } else {
    let buf = StringBuilder()
    let mut index = 0
    for char in molded {
      if index > 0 && index + 1 < count {
        buf.write_char(char)
      }
      index = index + 1
    }
    buf.to_string()
  }
}
