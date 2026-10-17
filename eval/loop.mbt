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
priv enum BodyEnd {
  Done(@value.Cell)
  Stop
  Skip
}

///|
/// Runs the block. `break` stops the loop. `continue` asks for another pass.
fn eval_body(
  env : Env,
  cell : @value.Cell,
  name : String,
) -> BodyEnd raise EvalError {
  Done(eval_block(env, cell, name)) catch {
    EvalError::Broken => Stop
    EvalError::Continued => Skip
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
        Stop => {
          kept = @value.Cell::None
          running = false
        }
        Skip => ()
        Done(value) => kept = value
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
      Stop => {
        result = @value.Cell::None
        running = false
      }
      Skip => ()
      Done(value) =>
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
      Stop => {
        kept = @value.Cell::None
        left = 0L
      }
      Skip => left = left - 1L
      Done(value) => {
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

///|
/// Sets one word to each value of a block or string, then evaluates the body.
fn perform_foreach(
  env : Env,
  word : @value.Cell,
  data : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  match word {
    @value.Sym(_, lexeme) => {
      let frame = @value.Frame::new()
      let slot = frame.ensure(lexeme.sym())
      let bound = match copied_block(body) {
        Some(series) => {
          @bind.bind(@value.Seq(series, 0), frame) |> ignore
          @value.Seq(series, 0)
        }
        None => raise EvalError::Cannot("foreach")
      }
      walk_foreach(env, frame, slot, data, bound)
    }
    _ => raise EvalError::Cannot("foreach")
  }
}

///|
fn walk_foreach(
  env : Env,
  frame : @value.Frame,
  slot : Int,
  data : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  match data {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      foreach_items(env, frame, slot, series, index, body)
    @value.Seq(series, index) if series.datatype() == @value.String =>
      foreach_chars(env, frame, slot, series, index, body)
    _ => raise EvalError::Cannot("foreach")
  }
}

///|
fn foreach_items(
  env : Env,
  frame : @value.Frame,
  slot : Int,
  series : @value.Series,
  index : Int,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let mut cursor = if index < 0 { 0 } else { index }
  let mut kept = @value.Cell::None
  let mut running = true
  while running && cursor < series.length() {
    match series.item(cursor) {
      Some(item) => {
        store(frame, slot, item.snapshot())
        match eval_body(env, body, "foreach") {
          Stop => {
            kept = @value.Cell::None
            running = false
          }
          Skip => cursor = cursor + 1
          Done(value) => {
            kept = value
            cursor = cursor + 1
          }
        }
      }
      None => running = false
    }
  }
  kept
}

///|
fn foreach_chars(
  env : Env,
  frame : @value.Frame,
  slot : Int,
  series : @value.Series,
  index : Int,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let mut cursor = if index < 0 { 0 } else { index }
  let mut kept = @value.Cell::None
  let mut running = true
  while running && cursor < series.length() {
    match series.code(cursor) {
      Some(code) => {
        store(frame, slot, @value.Char(code))
        match eval_body(env, body, "foreach") {
          Stop => {
            kept = @value.Cell::None
            running = false
          }
          Skip => cursor = cursor + 1
          Done(value) => {
            kept = value
            cursor = cursor + 1
          }
        }
      }
      None => running = false
    }
  }
  kept
}
