///|
/// Raises an error whose id is the second word. A block argument supplies
/// the values in order; anything else is the first value. Only that first
/// value is kept, molded into the error.
fn perform_cause_error(
  kind : @value.Cell,
  name : @value.Cell,
  args : @value.Cell,
) -> @value.Cell raise EvalError {
  let _ = as_word(kind, "cause-error")
  let id = as_word(name, "cause-error").spelling()
  let values = cause_values(args)
  let arg = if values.length() == 0 { "" } else { @mold.mold_text(values[0]) }
  raise EvalError::Caused(id, arg)
}

///|
fn cause_values(args : @value.Cell) -> Array[@value.Cell] {
  match args {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let values : Array[@value.Cell] = []
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(item) => values.push(item)
          None => ()
        }
        cursor = cursor + 1
      }
      values
    }
    other => [other]
  }
}
