///|
/// Evaluates a block argument. Anything else is refused.
fn eval_block(
  env : Env,
  cell : @value.Cell,
  name : String,
) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, _) if series.datatype() == @value.Block =>
      eval(env, cell)
    _ => raise EvalError::Cannot(name)
  }
}

///|
/// Runs the block. `break` stops the loop and yields `none`. `return` keeps going out.
fn eval_body(
  env : Env,
  cell : @value.Cell,
  name : String,
) -> @value.Cell? raise EvalError {
  Some(eval_block(env, cell, name)) catch {
    EvalError::Broken => None
    error => raise error
  }
}

///|
/// Repeats while the condition block is neither `false` nor `none`.
/// Stopping before the body has run yields `none`. Otherwise the last body value stays.
fn perform_while(
  env : Env,
  condition : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let mut kept = @value.Cell::None
  let mut running = true
  while running {
    let checked = eval_block(env, condition, "while")
    if checked is @value.Cell::Unset {
      raise EvalError::Cannot("while")
    } else if is_false(checked) {
      running = false
    } else {
      match eval_body(env, body, "while") {
        None => {
          kept = @value.Cell::None
          running = false
        }
        Some(value) => kept = value
      }
    }
  }
  kept
}

///|
/// Evaluates the body until it is truthy. The result is that last body value.
fn perform_until(env : Env, body : @value.Cell) -> @value.Cell raise EvalError {
  let mut result = @value.Cell::Unset
  let mut running = true
  while running {
    match eval_body(env, body, "until") {
      None => {
        result = @value.Cell::None
        running = false
      }
      Some(value) =>
        if value is @value.Cell::Unset {
          raise EvalError::Cannot("until")
        } else if is_false(value) {
          result = value
        } else {
          result = value
          running = false
        }
    }
  }
  result
}

///|
/// Repeats the body `count` times. A non-positive count yields `none`.
fn perform_loop(
  env : Env,
  count : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let mut left = loop_count(count)
  let mut kept = @value.Cell::None
  while left > 0L {
    match eval_body(env, body, "loop") {
      None => {
        kept = @value.Cell::None
        left = 0L
      }
      Some(value) => {
        kept = value
        left = left - 1L
      }
    }
  }
  kept
}

///|
fn loop_count(cell : @value.Cell) -> Int64 raise EvalError {
  match cell {
    @value.Integer(n) => n
    @value.Decimal(n) => n.to_int64()
    _ => raise EvalError::Cannot("loop")
  }
}
