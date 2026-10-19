///|
/// JSON text, as in `to-json` without indentation. A map becomes an object.
/// A word inside an array is molded, then written as a string.
/// The text `save` writes for a `.json` file.
fn encoded_json(env : Env, value : @value.Cell) -> String raise EvalError {
  match encode_json(env, value) {
    @value.Seq(series, index) => text_from(series, index)
    _ => raise EvalError::Cannot("save")
  }
}

///|
fn encode_json(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let buf = StringBuilder()
  json_emit(env, buf, value)
  text_series(buf.to_string())
}

///|
fn json_emit(
  env : Env,
  buf : StringBuilder,
  value : @value.Cell,
) -> Unit raise EvalError {
  match value {
    @value.None => buf.write_string("null")
    @value.Logic(true) => buf.write_string("true")
    @value.Logic(false) => buf.write_string("false")
    @value.Integer(n) => buf.write_string(n.to_string())
    @value.Decimal(_) => buf.write_string(@mold.mold_text(value))
    @value.Percent(n) => buf.write_string(@mold.mold_text(@value.Decimal(n)))
    @value.Map(map) => json_write_object(env, buf, map)
    @value.Object(frame) => json_write_frame(env, buf, frame)
    @value.Seq(series, index) => json_series(env, buf, series, index)
    _ => json_quote(buf, @mold.mold_text(value))
  }
}

///|
fn json_series(
  env : Env,
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
) -> Unit raise EvalError {
  let kind = series.datatype()
  if kind == @value.Block ||
    kind == @value.Paren ||
    kind == @value.Path ||
    kind == @value.SetPath {
    json_list(env, buf, series, index)
  } else if @value.text_series(kind) || kind == @value.Binary {
    json_quote(buf, @mold.form_text(@value.Seq(series, index)))
  } else {
    json_quote(buf, @mold.mold_text(@value.Seq(series, index)))
  }
}

///|
fn json_list(
  env : Env,
  buf : StringBuilder,
  series : @value.Series,
  index : Int,
) -> Unit raise EvalError {
  buf.write_char('[')
  let mut cursor = if index < 0 { 0 } else { index }
  let mut first = true
  while cursor < series.length() {
    match series.item(cursor) {
      Some(item) => {
        if !first {
          buf.write_char(',')
        }
        first = false
        json_emit(env, buf, item)
      }
      None => ()
    }
    cursor = cursor + 1
  }
  buf.write_char(']')
}

///|
/// Object fields are written in the order the words were created.
fn json_write_frame(
  env : Env,
  buf : StringBuilder,
  frame : @value.Frame,
) -> Unit raise EvalError {
  buf.write_char('{')
  let mut first = true
  for index in 0..<frame.length() {
    match (frame.sym(index), frame.get(index)) {
      (Some(sym), Some(value)) =>
        if !frame.is_hidden(index) {
          if !first {
            buf.write_char(',')
          }
          first = false
          json_quote(buf, env.symbols.canon(sym))
          buf.write_char(':')
          json_emit(env, buf, value)
        }
      _ => ()
    }
  }
  buf.write_char('}')
}

///|
fn json_write_object(
  env : Env,
  buf : StringBuilder,
  map : @value.MapValue,
) -> Unit raise EvalError {
  buf.write_char('{')
  let mut first = true
  for index in 0..<map.length() {
    match (map.key(index), map.value(index)) {
      (Some(key), Some(value)) => {
        if !first {
          buf.write_char(',')
        }
        first = false
        json_quote(buf, json_key_name(key))
        buf.write_char(':')
        json_emit(env, buf, value)
      }
      _ => ()
    }
  }
  buf.write_char('}')
}

///|
fn json_key_name(key : @value.Cell) -> String {
  match key {
    @value.Sym(_, lexeme) => lexeme.spelling()
    @value.Seq(series, _) if @value.text_series(series.datatype()) ||
      series.datatype() == @value.Binary => @mold.form_text(key)
    _ => @mold.mold_text(key)
  }
}

///|
fn json_quote(buf : StringBuilder, text : String) -> Unit {
  buf.write_char('"')
  for char in text {
    let code = char.to_int()
    if code == '"'.to_int() {
      buf.write_char('\\')
      buf.write_char('"')
    } else if code == '\\'.to_int() {
      buf.write_char('\\')
      buf.write_char('\\')
    } else if code == 8 {
      buf.write_char('\\')
      buf.write_char('b')
    } else if code == 12 {
      buf.write_char('\\')
      buf.write_char('f')
    } else if code == '\n'.to_int() {
      buf.write_char('\\')
      buf.write_char('n')
    } else if code == '\r'.to_int() {
      buf.write_char('\\')
      buf.write_char('r')
    } else if code == '\t'.to_int() {
      buf.write_char('\\')
      buf.write_char('t')
    } else if code < 32 {
      json_uhex(buf, code)
    } else {
      buf.write_char(char)
    }
  }
  buf.write_char('"')
}

///|
fn json_uhex(buf : StringBuilder, code : Int) -> Unit {
  buf.write_char('\\')
  buf.write_char('u')
  let digits : Array[Int] = []
  let mut value = code
  if value == 0 {
    digits.push(0)
  }
  while value > 0 {
    digits.push(value % 16)
    value = value / 16
  }
  while digits.length() < 4 {
    digits.push(0)
  }
  let mut index = digits.length() - 1
  while index >= 0 {
    buf.write_char(hex_digit(digits[index]))
    index = index - 1
  }
}
