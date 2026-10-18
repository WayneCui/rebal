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
