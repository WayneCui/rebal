///|
extern "C" fn c_read_line() -> String = "rebal_read_line"

///|
extern "C" fn c_line_status() -> Int = "rebal_line_status"

///|
#borrow(text)
extern "C" fn c_write_stdout(text : String, text_len : Int) -> Int = "rebal_write_stdout"

///|
priv struct ConsoleHost {
  lines : Array[String]
  mut written : String
}

///|
let console_host : ConsoleHost = { lines: [], written: "", }

///|
/// Queues one line for the next console `read`. The host uses this in tests
/// so a read does not wait on the real terminal.
pub fn push_console(line : String) -> Unit {
  console_host.lines.push(line)
}

///|
/// Text written to the console since the process started.
pub fn console_written() -> String {
  console_host.written
}

///|
/// `read` takes one line and drops the trailing newline. `write` forms the
/// value and sends it to the terminal. `query` reports a fixed window when
/// the host has no terminal size.
fn console_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  match action {
    "open" => {
      set_port_open(port, true)
      port
    }
    "close" => {
      set_port_open(port, false)
      port
    }
    "read" =>
      match next_console_line() {
        Some(text) => text_series(text)
        None => @value.None
      }
    "write" =>
      match extra {
        Some(value) => {
          emit_console(@mold.form_text(value))
          port
        }
        None => raise EvalError::Cannot("write")
      }
    "query" => console_query(env)
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn next_console_line() -> String? raise EvalError {
  if console_host.lines.length() > 0 {
    Some(trim_line(console_host.lines.remove(0)))
  } else {
    let text = c_read_line()
    if c_line_status() == 0 {
      Some(text)
    } else if c_line_status() == 1 {
      None
    } else {
      raise EvalError::Cannot("port")
    }
  }
}

///|
fn emit_console(text : String) -> Unit {
  console_host.written = console_host.written + text
  c_write_stdout(text, text.length()) |> ignore
}

///|
fn console_query(env : Env) -> @value.Cell raise EvalError {
  let info = @value.Frame::new()
  put_field(env, info, "window-cols", @value.Integer(80L))
  put_field(env, info, "window-rows", @value.Integer(25L))
  put_field(env, info, "buffer-cols", @value.Integer(80L))
  put_field(env, info, "buffer-rows", @value.Integer(25L))
  put_field(
    env,
    info,
    "length",
    @value.Integer(console_host.written.length().to_int64()),
  )
  @value.Object(info)
}

///|
fn trim_line(text : String) -> String {
  let mut end = text.length()
  if end > 0 && text[end - 1] == '\n' {
    end = end - 1
  }
  if end > 0 && text[end - 1] == '\r' {
    end = end - 1
  }
  text[0:end].to_owned()
}
