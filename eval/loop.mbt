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
/// Like `while [true] body`, but as a native so `return` leaves the caller
/// instead of being caught by a mezzanine wrapper function.
fn perform_forever(env : Env, body : @value.Cell) -> @value.Cell raise EvalError {
  let mut kept = @value.Cell::None
  let mut running = true
  while running {
    match eval_body(env, body, "forever") {
      Stop => {
        kept = @value.Cell::None
        running = false
      }
      Skip => ()
      Done(value) => kept = value
    }
  }
  kept
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
/// Sets `word` to 1..n (or to each series value) and evaluates the body.
/// A non-positive count or `none` yields `none`.
fn perform_repeat(
  env : Env,
  word : @value.Cell,
  value : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let sym = match word {
    @value.Sym(_, lexeme) => lexeme.sym()
    _ => raise EvalError::Cannot("repeat")
  }
  let frame = @value.Frame::new()
  let slot = frame.ensure(sym)
  let bound = match copied_block(body) {
    Some(series) => {
      @bind.bind(@value.Seq(series, 0), frame) |> ignore
      @value.Seq(series, 0)
    }
    None => raise EvalError::Cannot("repeat")
  }
  match value {
    @value.None => @value.None
    @value.Integer(_) | @value.Decimal(_) => {
      let limit = loop_count(value)
      if limit <= 0L {
        @value.None
      } else {
        let mut n = 1L
        let mut kept = @value.Cell::None
        let mut running = true
        while running && n <= limit {
          store(frame, slot, @value.Integer(n))
          match eval_body(env, bound, "repeat") {
            Stop => {
              kept = @value.Cell::None
              running = false
            }
            Skip => n = n + 1L
            Done(result) => {
              kept = result
              n = n + 1L
            }
          }
        }
        kept
      }
    }
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      foreach_groups(env, frame, [slot], series, index, bound)
    @value.Seq(series, index) if series.datatype() == @value.String =>
      foreach_chars(env, frame, slot, series, index, bound)
    _ => raise EvalError::Cannot("repeat")
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
  let syms = foreach_words(word)
  let frame = @value.Frame::new()
  let slots : Array[Int] = []
  for sym in syms {
    slots.push(frame.ensure(sym))
  }
  let bound = match copied_block(body) {
    Some(series) => {
      @bind.bind(@value.Seq(series, 0), frame) |> ignore
      @value.Seq(series, 0)
    }
    None => raise EvalError::Cannot("foreach")
  }
  walk_foreach(env, frame, slots, data, bound)
}

///|
/// Like `foreach`, but keeps every body result in a new block.
fn perform_map_each(
  env : Env,
  word : @value.Cell,
  data : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let syms = foreach_words(word)
  let frame = @value.Frame::new()
  let slots : Array[Int] = []
  for sym in syms {
    slots.push(frame.ensure(sym))
  }
  let bound = match copied_block(body) {
    Some(series) => {
      @bind.bind(@value.Seq(series, 0), frame) |> ignore
      @value.Seq(series, 0)
    }
    None => raise EvalError::Cannot("map-each")
  }
  match data {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let out = @value.Series::block()
      let width = slots.length()
      let mut cursor = if index < 0 { 0 } else { index }
      let mut running = true
      while running && cursor < series.length() {
        for nth in 0..<width {
          let value = match series.item(cursor + nth) {
            Some(item) => item.snapshot()
            None => @value.None
          }
          store(frame, slots[nth], value)
        }
        match eval_body(env, bound, "map-each") {
          Stop => running = false
          Skip => cursor = cursor + width
          Done(value) => {
            out.push_item(value) |> ignore
            cursor = cursor + width
          }
        }
      }
      @value.Seq(out, 0)
    }
    _ => raise EvalError::Cannot("map-each")
  }
}

///|
/// A single word, or a block of words for grouped or keyed passes.
fn foreach_words(word : @value.Cell) -> Array[Int] raise EvalError {
  match word {
    @value.Sym(_, lexeme) => [lexeme.sym()]
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let syms : Array[Int] = []
      let mut cursor = if index < 0 { 0 } else { index }
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(_, lexeme)) => syms.push(lexeme.sym())
          _ => raise EvalError::Cannot("foreach")
        }
        cursor = cursor + 1
      }
      if syms.length() == 0 {
        raise EvalError::Cannot("foreach")
      }
      syms
    }
    _ => raise EvalError::Cannot("foreach")
  }
}

///|
fn walk_foreach(
  env : Env,
  frame : @value.Frame,
  slots : Array[Int],
  data : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  match data {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      foreach_groups(env, frame, slots, series, index, body)
    @value.Seq(series, index) if series.datatype() == @value.String &&
      slots.length() == 1 =>
      foreach_chars(env, frame, slots[0], series, index, body)
    @value.Map(map) => foreach_entries(env, frame, slots, map, body)
    _ => raise EvalError::Cannot("foreach")
  }
}

///|
/// Each pass takes one item per word. A short tail leaves the rest `none`.
fn foreach_groups(
  env : Env,
  frame : @value.Frame,
  slots : Array[Int],
  series : @value.Series,
  index : Int,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let width = slots.length()
  let mut cursor = if index < 0 { 0 } else { index }
  let mut kept = @value.Cell::None
  let mut running = true
  while running && cursor < series.length() {
    for nth in 0..<width {
      let value = match series.item(cursor + nth) {
        Some(item) => item.snapshot()
        None => @value.None
      }
      store(frame, slots[nth], value)
    }
    match eval_body(env, body, "foreach") {
      Stop => {
        kept = @value.Cell::None
        running = false
      }
      Skip => cursor = cursor + width
      Done(value) => {
        kept = value
        cursor = cursor + width
      }
    }
  }
  kept
}

///|
/// A map walks its entries. One word is the key; two are key and value.
fn foreach_entries(
  env : Env,
  frame : @value.Frame,
  slots : Array[Int],
  map : @value.MapValue,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let mut kept = @value.Cell::None
  let mut running = true
  let mut at = 0
  while running && at < map.length() {
    for nth in 0..<slots.length() {
      let value = if nth == 0 {
        match map.key(at) {
          Some(key) => key
          None => @value.None
        }
      } else if nth == 1 {
        match map.value(at) {
          Some(found) => found
          None => @value.None
        }
      } else {
        @value.None
      }
      store(frame, slots[nth], value)
    }
    match eval_body(env, body, "foreach") {
      Stop => {
        kept = @value.Cell::None
        running = false
      }
      Skip => at = at + 1
      Done(value) => {
        kept = value
        at = at + 1
      }
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
