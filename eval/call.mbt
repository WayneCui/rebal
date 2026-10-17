///|
#borrow(packed, input)
extern "C" fn c_spawn(
  packed : String,
  packed_len : Int,
  flags : Int,
  input : String,
  input_len : Int,
) -> String = "rebal_spawn"

///|
extern "C" fn c_call_code() -> Int = "rebal_call_code"

///|
fn call_extra(env : Env, active : Array[Int]) -> Int raise EvalError {
  let mut extra = 0
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "input" || name == "output" {
      extra = extra + 1
    } else if name == "wait" || name == "shell" {
      ()
    } else {
      raise EvalError::Cannot("call")
    }
  }
  extra
}

///|
/// A string or file is one argument. A block is the argument list.
/// `/wait` returns the exit code. Without it, the result is the process id.
/// `/output` appends stdout onto a string and waits. `/shell` uses `/bin/sh -c`.
fn perform_call(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let shell = named(env, active, "shell")
  let wait = named(env, active, "wait")
  let command = command_args(args[0], shell)
  let mut slot = 1
  let input = if named(env, active, "input") {
    let text = input_text(args[slot])
    slot = slot + 1
    text
  } else {
    ""
  }
  let output = if named(env, active, "output") {
    match args[slot] {
      @value.Seq(series, _) if series.datatype() == @value.String =>
        Some(series)
      _ => raise EvalError::Cannot("call")
    }
  } else {
    None
  }
  let mut flags = 0
  if wait {
    flags = flags + 1
  }
  if shell {
    flags = flags + 2
  }
  if output is Some(_) {
    flags = flags + 4
  }
  let text = c_spawn(command, command.length(), flags, input, input.length())
  let code = c_call_code()
  if code < 0 {
    raise EvalError::Cannot("call")
  }
  match output {
    Some(series) =>
      for char in text {
        series.push_code(char.to_int()) |> ignore
      }
    None => ()
  }
  @value.Integer(code.to_int64())
}

///|
fn command_args(cell : @value.Cell, shell : Bool) -> String raise EvalError {
  if shell {
    match cell {
      @value.Seq(series, index) if series.datatype() == @value.String =>
        text_from(series, index)
      _ => raise EvalError::Cannot("call")
    }
  } else {
    let parts = command_parts(cell)
    let buf = StringBuilder()
    let mut first = true
    for part in parts {
      if !first {
        buf.write_char('\u0001')
      }
      first = false
      buf.write_string(part)
    }
    buf.to_string()
  }
}

///|
fn command_parts(cell : @value.Cell) -> Array[String] raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.String ||
      series.datatype() == @value.File => [text_from(series, index)]
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let parts : Array[String] = []
      let mut cursor = index
      while cursor < series.length() {
        parts.push(command_piece(series.item(cursor)))
        cursor = cursor + 1
      }
      if parts.length() == 0 {
        raise EvalError::Cannot("call")
      }
      parts
    }
    _ => raise EvalError::Cannot("call")
  }
}

///|
fn command_piece(cell : @value.Cell?) -> String raise EvalError {
  match cell {
    Some(@value.Seq(series, index)) if series.datatype() == @value.String ||
      series.datatype() == @value.File => text_from(series, index)
    Some(@value.Sym(_, lexeme)) => lexeme.spelling()
    _ => raise EvalError::Cannot("call")
  }
}

///|
fn input_text(cell : @value.Cell) -> String raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.File =>
      read_file(text_from(series, index))
    _ => raise EvalError::Cannot("call")
  }
}
