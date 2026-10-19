///|
/// Builds a new block. Parens are evaluated. A block result is spliced in,
/// unless `/only` is set. With `/deep`, nested blocks are composed too.
fn perform_compose(
  env : Env,
  cell : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut deep = false
  let mut only = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "deep" {
      deep = true
    } else if name == "only" {
      only = true
    } else {
      raise EvalError::Cannot("compose")
    }
  }
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      compose_block(env, series, index, deep, only)
    _ => raise EvalError::Cannot("compose")
  }
}

///|
fn compose_block(
  env : Env,
  series : @value.Series,
  index : Int,
  deep : Bool,
  only : Bool,
) -> @value.Cell raise EvalError {
  let out = @value.Series::block()
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.item(cursor) {
      Some(@value.Seq(nested, nested_index)) if nested.datatype() ==
        @value.Paren => {
        let value = eval(env, @value.Seq(nested, nested_index))
        if only {
          match value {
            @value.Unset => ()
            other => out.push_item(other) |> ignore
          }
        } else {
          splice(out, value)
        }
      }
      Some(@value.Seq(nested, nested_index)) if deep &&
        nested.datatype() == @value.Block =>
        out.push_item(compose_block(env, nested, nested_index, deep, only))
        |> ignore
      Some(item) => out.push_item(item.snapshot()) |> ignore
      None => ()
    }
    cursor = cursor + 1
  }
  @value.Seq(out, 0)
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
