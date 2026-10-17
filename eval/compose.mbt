///|
/// Builds a new block. Parens are evaluated. A block result is spliced in.
fn perform_compose(
  env : Env,
  cell : @value.Cell,
) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let out = @value.Series::block()
      let mut cursor = if index < 0 { 0 } else { index }
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Seq(nested, nested_index)) if nested.datatype() ==
            @value.Paren =>
            splice(out, eval(env, @value.Seq(nested, nested_index)))
          Some(item) => out.push_item(item.snapshot()) |> ignore
          None => ()
        }
        cursor = cursor + 1
      }
      @value.Seq(out, 0)
    }
    _ => raise EvalError::Cannot("compose")
  }
}

///|
fn splice(out : @value.Series, value : @value.Cell) -> Unit {
  match value {
    @value.Unset => ()
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let mut cursor = if index < 0 { 0 } else { index }
      while cursor < series.length() {
        match series.item(cursor) {
          Some(item) => out.push_item(item.snapshot()) |> ignore
          None => ()
        }
        cursor = cursor + 1
      }
    }
    other => out.push_item(other) |> ignore
  }
}
