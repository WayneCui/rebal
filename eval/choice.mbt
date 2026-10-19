///|
/// Skips one unevaluated expression, including a following infix chain.
fn skip_expr(
  env : Env,
  series : @value.Series,
  index : Int,
) -> Int raise EvalError {
  if index >= series.length() {
    index
  } else {
    let mut cursor = match series.item(index) {
      Some(@value.Sym(@value.SetWord, _)) => skip_expr(env, series, index + 1)
      _ => index + 1
    }
    let mut running = true
    while running {
      match infix_at(env, series, cursor) {
        Some(_) =>
          if cursor + 1 >= series.length() {
            raise EvalError::Cannot("case")
          } else {
            cursor = cursor + 2
          }
        None => running = false
      }
    }
    cursor
  }
}

///|
/// Takes the result of the first truthy condition. A block result is evaluated.
fn perform_case(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      walk_case(env, series, index)
    _ => raise EvalError::Cannot("case")
  }
}

///|
fn walk_case(
  env : Env,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let mut cursor = index
  let mut found : @value.Cell? = None
  while found is None && cursor < series.length() {
    let stepped = do_next_at(env, series, cursor)
    if stepped.1 <= cursor {
      raise EvalError::Cannot("case")
    }
    if is_false(stepped.0) {
      cursor = skip_expr(env, series, stepped.1)
    } else if stepped.1 >= series.length() {
      found = Some(@value.Logic(true))
    } else {
      let chosen = do_next_at(env, series, stepped.1)
      found = Some(eval_branch(env, chosen.0))
    }
  }
  match found {
    Some(value) => value
    None => @value.None
  }
}

///|
/// Selects the block that follows an equal match. Keys may share one
/// body block: `a b c [body]` runs that block for any of those keys.
/// `/default` evaluates its block when nothing matched.
fn perform_switch(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut has_default = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "default" {
      has_default = true
    } else {
      raise EvalError::Cannot("switch")
    }
  }
  let value = args[0]
  let cases = args[1]
  let fallback = if has_default { Some(args[2]) } else { None }
  match cases {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      walk_switch(env, value, series, index, fallback)
    _ => raise EvalError::Cannot("switch")
  }
}

///|
fn walk_switch(
  env : Env,
  value : @value.Cell,
  series : @value.Series,
  index : Int,
  fallback : @value.Cell?,
) -> @value.Cell raise EvalError {
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.item(cursor) {
      Some(@value.Seq(nested, _)) if nested.datatype() == @value.Block =>
        cursor = cursor + 1
      Some(candidate) =>
        if @action.equal(value, candidate) {
          let mut at = cursor + 1
          while at < series.length() {
            match series.item(at) {
              Some(@value.Seq(nested, nested_index)) if nested.datatype() ==
                @value.Block =>
                return do_series(env, nested, nested_index)
              Some(_) => at = at + 1
              None => at = series.length()
            }
          }
          return @value.None
        } else {
          cursor = cursor + 1
        }
      None => cursor = series.length()
    }
  }
  match fallback {
    Some(@value.Seq(nested, nested_index)) if nested.datatype() ==
      @value.Block => do_series(env, nested, nested_index)
    Some(_) => raise EvalError::Cannot("switch")
    None => @value.None
  }
}
