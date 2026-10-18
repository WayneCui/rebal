///|
/// Forms a value onto the console and returns unset. A block is reduced
/// first, keeping unset results, then formed without its brackets.
/// `print` adds a line break. `prin` does not. A paren is formed as it is.
fn perform_print(
  env : Env,
  value : @value.Cell,
  newline : Bool,
) -> @value.Cell raise EvalError {
  let shown = reduce_printed(env, value)
  emit_console(@mold.form_text(shown))
  if newline {
    emit_console("\n")
  }
  @value.Unset
}

///|
fn reduce_printed(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let out = @value.Series::block()
      let mut cursor = index
      while cursor < series.length() {
        let stepped = do_next_at(env, series, cursor)
        if stepped.1 <= cursor {
          raise EvalError::Cannot("reduce")
        }
        out.push_item(stepped.0) |> ignore
        cursor = stepped.1
      }
      @value.Seq(out, 0)
    }
    _ => cell
  }
}
