///|
/// Returns the first truthy value. Unset results are skipped. An empty walk is `none`.
fn perform_any(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => walk_any(env, series, index)
    _ => raise EvalError::Cannot("any")
  }
}

///|
fn walk_any(
  env : Env,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let mut cursor = index
  let mut found = @value.Cell::None
  let mut running = true
  while running && cursor < series.length() {
    let stepped = do_next_at(env, series, cursor)
    if stepped.1 <= cursor {
      raise EvalError::Cannot("any")
    }
    cursor = stepped.1
    match stepped.0 {
      @value.Unset => ()
      value =>
        if !is_false(value) {
          found = value
          running = false
        }
    }
  }
  found
}

///|
/// Returns `none` at the first false value. Otherwise returns the last value.
fn perform_all(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => walk_all(env, series, index)
    _ => raise EvalError::Cannot("all")
  }
}

///|
fn walk_all(
  env : Env,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let mut cursor = index
  let mut kept = @value.Cell::None
  let mut running = true
  while running && cursor < series.length() {
    let stepped = do_next_at(env, series, cursor)
    if stepped.1 <= cursor {
      raise EvalError::Cannot("all")
    }
    cursor = stepped.1
    match stepped.0 {
      @value.Unset => ()
      value =>
        if is_false(value) {
          kept = @value.Cell::None
          running = false
        } else {
          kept = value
        }
    }
  }
  kept
}
