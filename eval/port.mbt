///|
fn port_field(
  value : @value.PortValue,
  selector : @value.Cell,
) -> @value.Cell raise EvalError {
  match selector {
    @value.Sym(_, lexeme) =>
      if lexeme.spelling().to_lower() == "spec" {
        @value.Object(value.spec)
      } else if lexeme.spelling().to_lower() == "scheme" {
        @value.Object(value.scheme)
      } else {
        raise EvalError::InvalidPath(lexeme.spelling())
      }
    _ => raise EvalError::InvalidPath("port")
  }
}

///|
fn make_port(env : Env, spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Object(_) => port_from_object(env, spec)
    @value.Seq(series, _) if series.datatype() == @value.Block =>
      port_from_object(env, make_object(env, spec))
    @value.Seq(series, index) if series.datatype() == @value.File =>
      port_from_file(env, series, index, spec)
    @value.Seq(series, index) if series.datatype() == @value.Url =>
      port_from_url(env, series, index, spec)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn perform_open(env : Env, spec : @value.Cell) -> @value.Cell raise EvalError {
  let port = as_port(env, spec, "open")
  dispatch_port(env, "open", port, None)
}

///|
fn perform_close(env : Env, spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Port(_) => dispatch_port(env, "close", spec, None)
    _ => raise EvalError::Cannot("close")
  }
}

///|
fn perform_read(env : Env, spec : @value.Cell) -> @value.Cell raise EvalError {
  let port = as_port(env, spec, "read")
  dispatch_port(env, "read", port, None)
}

///|
fn perform_write(
  env : Env,
  spec : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let port = as_port(env, spec, "write")
  dispatch_port(env, "write", port, Some(value))
}

///|
fn perform_query(env : Env, spec : @value.Cell) -> @value.Cell raise EvalError {
  let port = as_port(env, spec, "query")
  dispatch_port(env, "query", port, None)
}

///|
/// Turns a port, file, or url into a port. Other values fail as `action`.
fn as_port(
  env : Env,
  spec : @value.Cell,
  action : String,
) -> @value.Cell raise EvalError {
  match spec {
    @value.Port(_) => spec
    @value.Seq(series, index) if series.datatype() == @value.File =>
      port_from_file(env, series, index, spec)
    @value.Seq(series, index) if series.datatype() == @value.Url =>
      port_from_url(env, series, index, spec)
    _ => raise EvalError::Cannot(action)
  }
}

///|
/// Scheme actors are added one at a time. A name with no actor is a failure.
fn dispatch_port(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  let name = match port {
    @value.Port(value) => value.name
    _ => raise EvalError::Cannot("port")
  }
  run_scheme(env, name, action, port, extra)
}

///|
fn run_scheme(
  env : Env,
  name : String,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  let _ = (env, name, action, port, extra)
  raise EvalError::Cannot("port")
}

///|
fn port_from_object(
  env : Env,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  match spec {
    @value.Object(frame) =>
      match frame_field(env, frame, "scheme") {
        Some(@value.Sym(_, lexeme)) => {
          let target = match frame_field(env, frame, "ref") {
            Some(cell) => cell
            None => @value.None
          }
          build_port(env, lexeme.spelling().to_lower(), target)
        }
        _ => raise EvalError::Cannot("make")
      }
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn port_from_file(
  env : Env,
  series : @value.Series,
  index : Int,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  let name = if ends_with_slash(series, index) { "dir" } else { "file" }
  build_port(env, name, spec)
}

///|
fn port_from_url(
  env : Env,
  series : @value.Series,
  index : Int,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  build_port(env, url_scheme(series, index), spec)
}

///|
fn build_port(
  env : Env,
  name : String,
  target : @value.Cell,
) -> @value.Cell raise EvalError {
  let spec = @value.Frame::new()
  put_field(env, spec, "scheme", word_cell(env, name))
  put_field(env, spec, "ref", target)
  let scheme = @value.Frame::new()
  put_field(env, scheme, "name", word_cell(env, name))
  @value.Port(@value.PortValue::make(spec, scheme, name))
}

///|
fn put_field(
  env : Env,
  frame : @value.Frame,
  spelling : String,
  cell : @value.Cell,
) -> Unit raise EvalError {
  let slot = frame.ensure(env.symbols.intern(spelling))
  store(frame, slot, cell)
}

///|
fn frame_field(
  env : Env,
  frame : @value.Frame,
  spelling : String,
) -> @value.Cell? {
  match frame.find(env.symbols.intern(spelling)) {
    Some(slot) => frame.get(slot)
    None => None
  }
}

///|
fn word_cell(env : Env, spelling : String) -> @value.Cell {
  let folded = spelling.to_lower()
  let sym = env.symbols.intern(folded)
  @value.Sym(@value.Word, @value.Lexeme::make(sym, folded))
}

///|
fn ends_with_slash(series : @value.Series, index : Int) -> Bool {
  let last = series.length() - 1
  if last < index {
    false
  } else {
    match series.code(last) {
      Some(code) => code == 47 || code == 92
      None => false
    }
  }
}

///|
fn url_scheme(series : @value.Series, index : Int) -> String raise EvalError {
  let buf = StringBuilder()
  let mut cursor = index
  let mut found = false
  while cursor < series.length() && !found {
    match series.code(cursor) {
      Some(58) => found = true
      Some(code) =>
        match code.to_char() {
          Some(char) => buf.write_char(char)
          None => raise EvalError::Cannot("make")
        }
      None => ()
    }
    cursor = cursor + 1
  }
  let name = buf.to_string().to_lower()
  if found && name.length() > 0 {
    name
  } else {
    raise EvalError::Cannot("make")
  }
}
