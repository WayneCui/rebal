///|
/// Eight bytes of the integer, most significant first, the way r3's
/// `to binary!` widens a number.
fn be64_bytes(n : Int64) -> Array[Int] {
  let bytes : Array[Int] = []
  let mut shift = 56
  while shift >= 0 {
    bytes.push(((n >> shift) & 0xFFL).to_int())
    shift = shift - 8
  }
  bytes
}

///|
/// One element of a `to binary!` block: an integer is a byte, a char and
/// text convert to UTF-8, a binary contributes its bytes.
fn push_binary_bytes(bytes : Array[Int], item : @value.Cell) -> Unit raise EvalError {
  match item {
    @value.Integer(n) =>
      if n >= 0L && n <= 255L {
        bytes.push(n.to_int())
      } else {
        raise EvalError::Cannot("to")
      }
    @value.Char(code) => push_utf8(bytes, code)
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let more = bytes_from(series, index)
      for byte in more {
        bytes.push(byte)
      }
    }
    @value.Seq(series, index) if @value.text_series(series.datatype()) => {
      let more = utf8_bytes(text_from(series, index))
      for byte in more {
        bytes.push(byte)
      }
    }
    _ => raise EvalError::Cannot("to")
  }
}

///|
/// `to binary!`: text converts to its UTF-8 bytes, a binary is copied, an
/// integer becomes its eight big-endian bytes, a tuple its bytes, and a
/// block joins the bytes of its elements.
fn to_binary_value(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      binary_cell(bytes_from(series, index))
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      binary_cell(utf8_bytes(text_from(series, index)))
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => {
      let bytes : Array[Int] = []
      let mut cursor = if index < 0 { 0 } else { index }
      while cursor < series.length() {
        match series.item(cursor) {
          Some(item) => push_binary_bytes(bytes, item)
          None => ()
        }
        cursor = cursor + 1
      }
      binary_cell(bytes)
    }
    @value.Char(code) => {
      let bytes : Array[Int] = []
      push_utf8(bytes, code)
      binary_cell(bytes)
    }
    @value.Integer(n) => binary_cell(be64_bytes(n))
    @value.Decimal(n) => binary_cell(be64_bytes(n.to_int64()))
    @value.Tuple(bytes) => binary_cell(bytes)
    _ => raise EvalError::Cannot("to")
  }
}

///|
/// `make binary!`: an integer only sets aside room for that many bytes, so
/// the result is empty like r3's. Anything else converts the `to` way.
fn make_binary_value(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Integer(_) => binary_cell([])
    _ => to_binary_value(spec)
  }
}
