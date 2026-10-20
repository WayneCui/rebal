///|
#borrow(host)
extern "C" fn c_tcp_connect(host : String, host_len : Int, port : Int) -> Int = "rebal_tcp_connect"

///|
#borrow(host)
extern "C" fn c_tcp_listen(host : String, host_len : Int, port : Int) -> Int = "rebal_tcp_listen"

///|
extern "C" fn c_tcp_listen_code() -> Int = "rebal_tcp_listen_code"

///|
extern "C" fn c_tcp_bound_port() -> Int = "rebal_tcp_bound_port_get"

///|
extern "C" fn c_tcp_accept(listen_fd : Int) -> Int = "rebal_tcp_accept"

///|
#borrow(text)
extern "C" fn c_tcp_send(handle : Int, text : String, text_len : Int) -> Int = "rebal_tcp_send"

///|
#borrow(data)
extern "C" fn c_tcp_send_bytes(
  handle : Int,
  data : String,
  data_len : Int,
) -> Int = "rebal_tcp_send_bytes"

///|
extern "C" fn c_tcp_recv(handle : Int) -> String = "rebal_tcp_recv"

///|
extern "C" fn c_tcp_recv_bytes(handle : Int) -> String = "rebal_tcp_recv_bytes"

///|
extern "C" fn c_tcp_code() -> Int = "rebal_tcp_code"

///|
extern "C" fn c_tcp_close(handle : Int) -> Int = "rebal_tcp_close"

///|
extern "C" fn c_tcp_echo() -> Int = "rebal_tcp_echo"

///|
#borrow(data)
extern "C" fn c_tcp_probe(port : Int, data : String, data_len : Int) -> Int = "rebal_tcp_probe"

///|
extern "C" fn c_tcp_probe_code() -> Int = "rebal_tcp_probe_code"

///|
extern "C" fn c_tcp_probe_result() -> String = "rebal_tcp_probe_result"

///|
extern "C" fn c_poll_clear() -> Unit = "rebal_poll_clear"

///|
extern "C" fn c_poll_add(fd : Int, tag : Int) -> Int = "rebal_poll_add"

///|
extern "C" fn c_poll_wait(timeout_ms : Int) -> Int = "rebal_poll_wait"

///|
extern "C" fn c_poll_ready_fd_at(index : Int) -> Int = "rebal_poll_ready_fd_at"

///|
extern "C" fn c_poll_ready_tag_at(index : Int) -> Int = "rebal_poll_ready_tag_at"

///|
/// Async TCP ports watched by `wait` even when only the listen port is listed.
let watched_ports : Array[@value.Cell] = []

///|
fn watch_port(cell : @value.Cell) -> Unit {
  for existing in watched_ports {
    if existing.same(cell) {
      return
    }
  }
  watched_ports.push(cell)
}

///|
fn unwatch_port(cell : @value.Cell) -> Unit {
  let rest : Array[@value.Cell] = []
  for existing in watched_ports {
    if !existing.same(cell) {
      rest.push(existing)
    }
  }
  watched_ports.clear()
  for item in rest {
    watched_ports.push(item)
  }
}

///|
/// Listens on 127.0.0.1 and echoes one line, then closes. Returns the port.
pub fn tcp_echo() -> Int {
  c_tcp_echo()
}

///|
/// Background client for listen/accept tests. Sends `data` to `port` and
/// stores the reply for `tcp_probe_result`.
pub fn tcp_probe(port : Int, data : String) -> Int {
  c_tcp_probe(port, data, data.length())
}

///|
pub fn tcp_probe_code() -> Int {
  c_tcp_probe_code()
}

///|
pub fn tcp_probe_result() -> String {
  c_tcp_probe_result()
}

///|
/// `open` connects to `tcp://host:port`, or listens when the host is empty
/// (`tcp://:8080`). Listen/async ports use `wait` + `awake` events.
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
  if host.length() == 0 {
    tcp_open_listen(env, port, number)
  } else {
    tcp_open_connect(port, host, number)
  }
}

///|
fn tcp_open_connect(
  port : @value.Cell,
  host : String,
  number : Int,
) -> @value.Cell raise EvalError {
  let handle = c_tcp_connect(host, host.length(), number)
  if handle < 0 {
    raise EvalError::Cannot("access")
  }
  match port {
    @value.Port(value) => {
      value.set_handle(handle)
      value.set_opened(true)
      value.set_kind(@value.PortKind::tcp_sync())
    }
    _ => ()
  }
  port
}

///|
fn tcp_open_listen(
  env : Env,
  port : @value.Cell,
  number : Int,
) -> @value.Cell raise EvalError {
  let handle = c_tcp_listen("", 0, number)
  if handle < 0 || c_tcp_listen_code() != 0 {
    raise EvalError::Cannot("access")
  }
  let bound = c_tcp_bound_port()
  match port {
    @value.Port(value) => {
      value.set_handle(handle)
      value.set_opened(true)
      value.set_kind(@value.PortKind::tcp_listen())
      put_field(env, value.spec, "host", @value.None)
      put_field(env, value.spec, "port", @value.Integer(bound.to_int64()))
    }
    _ => ()
  }
  watch_port(port)
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
      value.set_want_read(false)
      value.set_pending_wrote(false)
    }
    _ => ()
  }
  unwatch_port(port)
  port
}

///|
fn tcp_read(port : @value.Cell) -> @value.Cell raise EvalError {
  match port {
    @value.Port(value) =>
      match value.kind() {
        @value.PortKind::TcpAsync => {
          value.set_want_read(true)
          watch_port(port)
          port
        }
        @value.PortKind::TcpListen => raise EvalError::Cannot("port")
        @value.PortKind::TcpSync => {
          let text = c_tcp_recv(tcp_handle(port))
          if c_tcp_code() == 0 {
            text_series(text)
          } else {
            raise EvalError::Cannot("access")
          }
        }
      }
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn tcp_write(
  port : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  match port {
    @value.Port(pval) =>
      match pval.kind() {
        @value.PortKind::TcpAsync => {
          tcp_write_bytes(port, value)
          pval.set_pending_wrote(true)
          watch_port(port)
          port
        }
        @value.PortKind::TcpListen => raise EvalError::Cannot("port")
        @value.PortKind::TcpSync => {
          let text = match value {
            @value.Seq(series, index) if series.datatype() == @value.String =>
              text_from(series, index)
            @value.Seq(series, index) if series.datatype() == @value.Binary =>
              latin_text(bytes_from(series, index))
            _ => @mold.mold_text(value)
          }
          if c_tcp_send(tcp_handle(port), text, text.length()) == 0 {
            port
          } else {
            raise EvalError::Cannot("access")
          }
        }
      }
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn tcp_write_bytes(
  port : @value.Cell,
  value : @value.Cell,
) -> Unit raise EvalError {
  let bytes = match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.String =>
      utf8_bytes(text_from(series, index))
    _ => utf8_bytes(@mold.mold_text(value))
  }
  let packed = latin_text(bytes)
  if c_tcp_send_bytes(tcp_handle(port), packed, bytes.length()) != 0 {
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
/// `first` of a listen port takes the next accepted connection.
fn tcp_first(port : @value.Cell) -> @value.Cell raise EvalError {
  match port {
    @value.Port(value) =>
      match value.kind() {
        @value.PortKind::TcpListen =>
          match value.take_accept() {
            Some(child) => child
            None => raise EvalError::Cannot("port")
          }
        _ => raise EvalError::Cannot("port")
      }
    _ => raise EvalError::Cannot("port")
  }
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
/// `tcp://host:port` connects. `tcp://:port` (empty host) listens. Port may
/// be 0 to ask the OS for an ephemeral port.
fn split_tcp(text : String) -> (String, Int) raise EvalError {
  let mark = tcp_mark(text)
  if mark < 0 {
    raise EvalError::Cannot("port")
  }
  let rest = text[mark:text.length()].to_owned()
  let colon = last_colon(rest)
  if colon < 0 || colon + 1 >= rest.length() {
    raise EvalError::Cannot("port")
  }
  let host = if colon == 0 { "" } else { rest[0:colon].to_owned() }
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
  if number < 0 || number > 65535 {
    raise EvalError::Cannot("port")
  }
  number
}

///|
fn make_async_tcp_port(env : Env, handle : Int) -> @value.Cell raise EvalError {
  let port = build_port(env, "tcp", @value.None)
  match port {
    @value.Port(value) => {
      value.set_handle(handle)
      value.set_opened(true)
      value.set_kind(@value.PortKind::tcp_async())
    }
    _ => ()
  }
  watch_port(port)
  port
}
