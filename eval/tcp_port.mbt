///|
#borrow(host)
extern "C" fn c_tcp_connect(host : String, host_len : Int, port : Int) -> Int = "rebal_tcp_connect"

///|
#borrow(text)
extern "C" fn c_tcp_send(handle : Int, text : String, text_len : Int) -> Int = "rebal_tcp_send"

///|
extern "C" fn c_tcp_recv(handle : Int) -> String = "rebal_tcp_recv"

///|
extern "C" fn c_tcp_code() -> Int = "rebal_tcp_code"

///|
extern "C" fn c_tcp_close(handle : Int) -> Int = "rebal_tcp_close"

///|
extern "C" fn c_tcp_echo() -> Int = "rebal_tcp_echo"

///|
/// Listens on 127.0.0.1 and echoes one line, then closes. Returns the port.
pub fn tcp_echo() -> Int {
  c_tcp_echo()
}

///|
/// `open` connects to `tcp://host:port`. `read` takes bytes until the peer
/// closes. `write` sends text. Only an IPv4 address is accepted.
fn tcp_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  match action {
    "open" => tcp_open(env, port)
    "close" => tcp_close(port)
    "read" => tcp_read(port)
    "write" =>
      match extra {
        Some(value) => tcp_write(port, value)
        None => raise EvalError::Cannot("write")
      }
    "query" => tcp_query(env, port)
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn tcp_open(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let (host, number) = tcp_address(env, port)
  let handle = c_tcp_connect(host, host.length(), number)
  if handle < 0 {
    raise EvalError::Cannot("access")
  }
  match port {
    @value.Port(value) => {
      value.set_handle(handle)
      value.set_opened(true)
    }
    _ => ()
  }
  port
}

///|
fn tcp_close(port : @value.Cell) -> @value.Cell {
  match port {
    @value.Port(value) => {
      if value.handle() >= 0 {
        c_tcp_close(value.handle()) |> ignore
        value.set_handle(-1)
      }
      value.set_opened(false)
    }
    _ => ()
  }
  port
}

///|
fn tcp_read(port : @value.Cell) -> @value.Cell raise EvalError {
  let text = c_tcp_recv(tcp_handle(port))
  if c_tcp_code() == 0 {
    text_series(text)
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn tcp_write(
  port : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index)
    _ => @mold.mold_text(value)
  }
  if c_tcp_send(tcp_handle(port), text, text.length()) == 0 {
    port
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn tcp_query(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let info = @value.Frame::new()
  put_field(env, info, "name", port_ref(env, port))
  put_field(env, info, "size", @value.None)
  put_field(env, info, "type", word_cell(env, "tcp"))
  @value.Object(info)
}

///|
fn tcp_handle(port : @value.Cell) -> Int raise EvalError {
  match port {
    @value.Port(value) => value.handle()
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn tcp_address(env : Env, port : @value.Cell) -> (String, Int) raise EvalError {
  match port_ref(env, port) {
    @value.Seq(series, index) if series.datatype() == @value.Url =>
      split_tcp(text_from(series, index))
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn split_tcp(text : String) -> (String, Int) raise EvalError {
  let mark = tcp_mark(text)
  if mark < 0 {
    raise EvalError::Cannot("port")
  }
  let rest = text[mark:text.length()].to_owned()
  let colon = last_colon(rest)
  if colon <= 0 || colon + 1 >= rest.length() {
    raise EvalError::Cannot("port")
  }
  let host = rest[0:colon].to_owned()
  let number = parse_port(rest[colon + 1:rest.length()].to_owned())
  (host, number)
}

///|
fn tcp_mark(text : String) -> Int {
  let mut index = 0
  while index + 2 < text.length() {
    if text[index] == ':' && text[index + 1] == '/' && text[index + 2] == '/' {
      return index + 3
    }
    index = index + 1
  }
  -1
}

///|
fn last_colon(text : String) -> Int {
  let mut found = -1
  let mut index = 0
  while index < text.length() {
    if text[index] == ':' {
      found = index
    }
    index = index + 1
  }
  found
}

///|
fn parse_port(text : String) -> Int raise EvalError {
  if text.length() == 0 {
    raise EvalError::Cannot("port")
  }
  let mut number = 0
  let mut index = 0
  while index < text.length() {
    let code = text[index].to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      raise EvalError::Cannot("port")
    }
    number = number * 10 + (code - '0'.to_int())
    index = index + 1
  }
  if number < 1 || number > 65535 {
    raise EvalError::Cannot("port")
  }
  number
}
