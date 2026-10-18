///|
/// Braille text, as in codec-braille.reb. Codes below 255 move into the
/// Braille block. Codes already there move back on decode.
fn encode_braille(value : @value.Cell) -> @value.Cell raise EvalError {
  text_series(braille_shift(braille_text(value), 10240, true))
}

///|
fn decode_braille(value : @value.Cell) -> @value.Cell raise EvalError {
  text_series(braille_shift(braille_text(value), 10240, false))
}

///|
fn braille_text(value : @value.Cell) -> String raise EvalError {
  match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      text_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      string_text(@value.Seq(series, index))
    @value.Seq(series, _) if series.datatype() == @value.File =>
      source_text(value)
    _ => raise EvalError::Cannot("encode")
  }
}

///|
fn braille_shift(text : String, base : Int, encode : Bool) -> String {
  let buf = StringBuilder()
  for char in text {
    let code = char.to_int()
    let shifted = if encode {
      if code < 255 {
        code + base
      } else {
        code
      }
    } else if code >= base && code <= base + 255 {
      code - base
    } else {
      code
    }
    match shifted.to_char() {
      Some(out) => buf.write_char(out)
      None => buf.write_char(char)
    }
  }
  buf.to_string()
}
