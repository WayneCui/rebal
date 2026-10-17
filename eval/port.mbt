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
    @value.Sym(@value.Word, lexeme) =>
      build_port(env, lexeme.spelling().to_lower(), @value.None)
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
  let port = ready_port(env, spec, "read")
  dispatch_port(env, "read", port, None)
}

///|
fn perform_write(
  env : Env,
  spec : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let port = ready_port(env, spec, "write")
  dispatch_port(env, "write", port, Some(value))
}

///|
fn perform_query(env : Env, spec : @value.Cell) -> @value.Cell raise EvalError {
  let port = ready_port(env, spec, "query")
  dispatch_port(env, "query", port, None)
}

///|
/// A port must already be open. A file or url is opened for this one call.
fn ready_port(
  env : Env,
  spec : @value.Cell,
  action : String,
) -> @value.Cell raise EvalError {
  match spec {
    @value.Port(value) =>
      if value.is_open() {
        spec
      } else {
        raise EvalError::Cannot("port")
      }
    _ => {
      let port = as_port(env, spec, action)
      match port {
        @value.Port(value) => value.set_opened(true)
        _ => ()
      }
      port
    }
  }
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
    @value.Sym(@value.Word, lexeme) =>
      build_port(env, lexeme.spelling().to_lower(), @value.None)
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
  if name == "file" {
    file_actor(env, action, port, extra)
  } else if name == "system" {
    system_actor(env, action, port, extra)
  } else if name == "console" {
    console_actor(env, action, port, extra)
  } else if name == "dir" {
    dir_actor(env, action, port, extra)
  } else if name == "tcp" {
    tcp_actor(env, action, port, extra)
  } else if name == "udp" {
    udp_actor(env, action, port, extra)
  } else if name == "http" {
    http_actor(env, action, port, extra)
  } else {
    let _ = (env, action, port, extra)
    raise EvalError::Cannot("port")
  }
}

///|
fn file_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  match action {
    "open" => {
      match port {
        @value.Port(value) => value.set_opened(true)
        _ => ()
      }
      port
    }
    "close" => {
      match port {
        @value.Port(value) => value.set_opened(false)
        _ => ()
      }
      port
    }
    "read" => read_text_port(env, port)
    "write" =>
      match extra {
        Some(value) => write_text_port(env, port, value)
        None => raise EvalError::Cannot("write")
      }
    "query" => query_text_port(env, port)
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn read_text_port(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  text_series(read_file(port_path(env, port)))
}

///|
fn write_text_port(
  env : Env,
  port : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index)
    _ => @mold.mold_text(value)
  }
  write_file(port_path(env, port), text)
  port
}

///|
fn query_text_port(
  env : Env,
  port : @value.Cell,
) -> @value.Cell raise EvalError {
  let path = port_path(env, port)
  let text = read_file(path)
  let info = @value.Frame::new()
  put_field(env, info, "name", port_ref(env, port))
  put_field(env, info, "size", @value.Integer(text.length().to_int64()))
  put_field(env, info, "type", word_cell(env, "file"))
  @value.Object(info)
}

///|
fn port_path(env : Env, port : @value.Cell) -> String raise EvalError {
  match port_ref(env, port) {
    @value.Seq(series, index) if series.datatype() == @value.File =>
      text_from(series, index)
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn port_ref(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  match port {
    @value.Port(value) =>
      match frame_field(env, value.spec, "ref") {
        Some(cell) => cell
        None => raise EvalError::Cannot("port")
      }
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn text_series(text : String) -> @value.Cell {
  let series = @value.Series::text()
  for char in text {
    series.push_code(char.to_int()) |> ignore
  }
  @value.Seq(series, 0)
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
