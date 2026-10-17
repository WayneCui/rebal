///|
#borrow(host)
extern "C" fn c_udp_connect(host : String, host_len : Int, port : Int) -> Int = "rebal_udp_connect"

///|
#borrow(text)
extern "C" fn c_udp_send(handle : Int, text : String, text_len : Int) -> Int = "rebal_udp_send"

///|
extern "C" fn c_udp_recv(handle : Int) -> String = "rebal_udp_recv"

///|
extern "C" fn c_udp_code() -> Int = "rebal_udp_code"

///|
extern "C" fn c_udp_echo() -> Int = "rebal_udp_echo"

///|
/// Listens on 127.0.0.1 and echoes one datagram. Returns the port.
pub fn udp_echo() -> Int {
  c_udp_echo()
}

///|
/// `open` aims a datagram socket at `udp://host:port`. `write` sends one
/// datagram and `read` takes one. Only an IPv4 address is accepted.
fn udp_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  match action {
    "open" => udp_open(env, port)
    "close" => udp_close(port)
    "read" => udp_read(port)
    "write" =>
      match extra {
        Some(value) => udp_write(port, value)
        None => raise EvalError::Cannot("write")
      }
    "query" => udp_query(env, port)
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn udp_open(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let (host, number) = udp_address(env, port)
  let handle = c_udp_connect(host, host.length(), number)
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
fn udp_close(port : @value.Cell) -> @value.Cell {
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
fn udp_read(port : @value.Cell) -> @value.Cell raise EvalError {
  let text = c_udp_recv(udp_handle(port))
  if c_udp_code() == 0 {
    text_series(text)
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn udp_write(
  port : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index)
    _ => @mold.mold_text(value)
  }
  if c_udp_send(udp_handle(port), text, text.length()) == 0 {
    port
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn udp_query(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let info = @value.Frame::new()
  put_field(env, info, "name", port_ref(env, port))
  put_field(env, info, "size", @value.None)
  put_field(env, info, "type", word_cell(env, "udp"))
  @value.Object(info)
}

///|
fn udp_handle(port : @value.Cell) -> Int raise EvalError {
  match port {
    @value.Port(value) => value.handle()
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn udp_address(env : Env, port : @value.Cell) -> (String, Int) raise EvalError {
  match port_ref(env, port) {
    @value.Seq(series, index) if series.datatype() == @value.Url =>
      split_tcp(text_from(series, index))
    _ => raise EvalError::Cannot("port")
  }
}
